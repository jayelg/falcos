//! module.kdl: the module author's file.
//!
//! Required for every module. Holds only facts nothing can discover by
//! looking at the directory, which is why there is no entry here for
//! files/, selinux/, finalize.sh or a repo file: those are presence
//! driven, and a declaration beside an existing file could drift both
//! ways.

use crate::asset::{self, Asset};
use crate::diag::{Issue, Issues};
use crate::list::{Entry, List};
use crate::options::{self, Opt, Variant};
use kdl::{KdlDocument, KdlNode};
use miette::SourceSpan;
use std::collections::BTreeMap;
use std::path::Path;

/// A batch of packages keyed to a base family, with an optional repo to
/// enable for just this install.
#[derive(Debug)]
pub struct PackageGroup {
    pub family: String,
    pub packages: Vec<String>,
    pub enablerepo: Option<String>,
    pub span: SourceSpan,
}

/// A capability or contract path, and where it was declared.
pub struct Decl {
    pub name: String,
    pub span: SourceSpan,
}

/// A filename this module collects from every other module that ships
/// one, and where the build puts them. Only the destination is declared,
/// because it is the one part that cannot be derived from the filename;
/// a contributor declares nothing at all.
///
/// Deliberately says nothing about what the consuming module then does
/// with them. The build collects; interpreting the result is the
/// module's business.
pub struct Collect {
    pub file: String,
    pub into: String,
    pub span: SourceSpan,
}

pub struct Module {
    /// The list path, which is the module's identity everywhere. These
    /// three carry the module's source for the graph checks that read
    /// several manifests at once and have to point back into each.
    #[allow(dead_code)]
    pub path: String,
    /// Where the directory actually is, relative to `modules/`. The same
    /// as `path` in tree, and under the fetch root for a pinned module.
    pub dir: String,
    #[allow(dead_code)]
    pub file: String,
    #[allow(dead_code)]
    pub text: String,
    pub description: String,
    pub supports: Vec<String>,
    /// Capabilities. Depend on these rather than on paths, so swapping a
    /// provider does not break a consumer.
    pub provides: Vec<Decl>,
    pub requires: Vec<Decl>,
    /// Soft: ordering and cache preference, never fails. Two edge kinds
    /// is enough to express everything here, and each additional one
    /// multiplies the ways a sort can go wrong.
    pub after: Vec<Decl>,
    /// Exact paths one module writes and another reads.
    pub provides_files: Vec<Decl>,
    /// The subset of `provides_files` declared `build-only=#true`: a real
    /// contract while the image builds, and gone from the shipped one
    /// because the providing module removes it again. Kept beside the
    /// full set rather than filtered out of it, so the ordering graph and
    /// the `requires-file` check still see every provider.
    pub provides_files_build_only: Vec<String>,
    pub requires_files: Vec<Decl>,
    /// Paths this module's files/ overlay knowingly replaces. Two
    /// overlays writing the same path is an error without one of these,
    /// because the winner is otherwise decided by build order and
    /// nothing says it was meant to.
    pub overrides: Vec<Decl>,
    /// The flavor this module is gated to, from the list rather than the
    /// manifest: a module never names a flavor.
    pub flavor: Option<String>,
    pub collects: Vec<Collect>,
    /// Build inputs the field sets cover, so that needing a secret or a
    /// build arg does not force a module to hand-write a whole RUN block.
    pub secrets: Vec<Decl>,
    pub args: Vec<Decl>,
    pub options: Vec<Opt>,
    pub variants: Vec<Variant>,
    /// Pinned upstream payloads, resolved into env on the layer. The
    /// version, the hash and the URL used to live in three places, one of
    /// them another file entirely.
    pub assets: Vec<Asset>,
    /// Packages keyed to base family, installed by the generator before
    /// module.sh runs. A package set lint can inspect, and one batched
    /// transaction per layer where there used to be scattered calls.
    pub packages: Vec<PackageGroup>,
    /// Resolved option name to value, ready to become env on the layer.
    pub resolved: Vec<(String, String)>,
    /// Where a Containerfile.inc goes relative to the generated block,
    /// and whether that block is emitted at all. Both only mean anything
    /// beside a fragment, which is why shipping one stays presence
    /// driven and only these two facts are declared.
    pub fragment_after: bool,
    pub standard_layer: bool,
}

/// The only base family today. Declared rather than assumed so that a
/// module that cannot build on a second one says so before it is tried.
const FAMILIES: [&str; 1] = ["fedora"];

const TOKEN_HELP: &str = "package names and repo IDs are emitted straight into the RUN line, so they are limited to letters, digits and . _ + : -; anything else belongs in module.sh, where it can be quoted deliberately";

/// Why a package name or repo ID is not safe to emit, or None when it is.
///
/// An allowlist rather than a list of characters to reject: the rejecting
/// version omitted the space, which is the one that actually splits a
/// name into two arguments, and every future omission would be silent in
/// the same way. This matters more than it did, because Stage 10 accepts
/// manifests from repositories this one does not control.
///
/// The permitted set is what an RPM spec legitimately holds: `+` for
/// gcc-c++, `.` for a version or an arch qualifier, `:` for an epoch, `-`
/// and `_` for ordinary names. None of them mean anything to the shell.
fn bad_token(value: &str) -> Option<&'static str> {
    if value.is_empty() {
        return Some("is empty");
    }
    // dnf5 would read it as a flag rather than as something to install.
    if value.starts_with('-') {
        return Some("starts with a dash");
    }
    if !value
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || "._+:-".contains(c))
    {
        return Some("has a character that is not allowed");
    }
    None
}

fn prop<'a>(node: &'a KdlNode, key: &str) -> Option<&'a str> {
    node.entries()
        .iter()
        .find(|e| e.name().map(|n| n.value()) == Some(key))
        .and_then(|e| e.value().as_string())
}

/// The first unnamed entry of a node, as a string.
fn string_args(node: &KdlNode) -> Vec<&str> {
    node.entries()
        .iter()
        .filter(|e| e.name().is_none())
        .filter_map(|e| e.value().as_string())
        .collect()
}

impl Module {
    pub fn load(entry: &Entry, list: &List, root: &Path, issues: &mut Issues) -> Option<Self> {
        // A pinned module keeps its list name as its identity but lives
        // under the fetch root, so a name that is also an in-tree module
        // would make every message about it ambiguous.
        if entry.remote.is_some() && root.join("modules").join(&entry.path).is_dir() {
            issues.push(
                Issue::new(
                    format!("`{}` is pinned but also exists in tree", entry.path),
                    &list.file,
                    &list.text,
                )
                .at(entry.span, "two modules would answer to this name")
                .help(format!(
                    "rename the pinned one, or drop modules/{}",
                    entry.path
                )),
            );
        }

        let dir = root.join("modules").join(entry.dir());
        let path = dir.join("module.kdl");
        let file = path.display().to_string();

        let Ok(text) = std::fs::read_to_string(&path) else {
            issues.push(
                Issue::new(
                    format!("`{}` has no module.kdl", entry.path),
                    &list.file,
                    &list.text,
                )
                .at(entry.span, "every module needs a manifest")
                .help(match entry.remote {
                    // The pin is fetched by generate and by lint, so the
                    // usual reason for this is a manifest run by hand
                    // before either has happened.
                    Some(_) => "run ./scripts/fetch-modules.sh to fetch what image.kdl pins"
                        .to_string(),
                    None => format!(
                        "create {file}; modules/_template/module-name/module.kdl is a copy-me reference"
                    ),
                }),
            );
            return None;
        };

        let doc: KdlDocument = match text.parse() {
            Ok(doc) => doc,
            Err(err) => {
                eprintln!("{:?}", miette::Report::new(err));
                issues.push(Issue::new(format!("{file} is not valid KDL"), &file, &text));
                return None;
            }
        };

        let mut module = Module {
            path: entry.path.clone(),
            dir: entry.dir(),
            description: String::new(),
            supports: Vec::new(),
            provides: Vec::new(),
            requires: Vec::new(),
            after: Vec::new(),
            provides_files: Vec::new(),
            provides_files_build_only: Vec::new(),
            requires_files: Vec::new(),
            overrides: Vec::new(),
            flavor: entry.flavor.clone(),
            collects: Vec::new(),
            secrets: Vec::new(),
            args: Vec::new(),
            options: Vec::new(),
            variants: Vec::new(),
            assets: Vec::new(),
            packages: Vec::new(),
            resolved: Vec::new(),
            fragment_after: false,
            standard_layer: true,
            file: file.clone(),
            text: text.clone(),
        };

        let mut fragment_span: Option<SourceSpan> = None;
        for node in doc.nodes() {
            match node.name().value() {
                "description" => match string_args(node).first() {
                    Some(d) if !d.is_empty() => module.description = d.to_string(),
                    _ => issues.push(
                        Issue::new("`description` needs a string", &file, &text)
                            .at(node.name().span(), "no description given"),
                    ),
                },
                "supports" => {
                    for family in string_args(node) {
                        if !FAMILIES.contains(&family) {
                            issues.push(
                                Issue::new(format!("unknown base family `{family}`"), &file, &text)
                                    .at(
                                        node.name().span(),
                                        "not a family this repository builds on",
                                    )
                                    .help(format!("known families: {}", FAMILIES.join(", "))),
                            );
                        }
                        module.supports.push(family.to_string());
                    }
                }
                kind @ ("provides" | "requires" | "after") => {
                    let decls = string_args(node)
                        .iter()
                        .map(|c| Decl {
                            name: c.to_string(),
                            span: node.name().span(),
                        })
                        .collect::<Vec<_>>();
                    if decls.is_empty() {
                        issues.push(
                            Issue::new(format!("`{kind}` needs a capability name"), &file, &text)
                                .at(node.name().span(), "nothing named"),
                        );
                    }
                    match kind {
                        "provides" => module.provides.extend(decls),
                        "requires" => module.requires.extend(decls),
                        _ => module.after.extend(decls),
                    }
                }
                kind @ ("provides-file" | "requires-file" | "overrides") => {
                    // `build-only=#true` marks a path the module writes for
                    // later build layers and removes again in its finalize
                    // hook, so it is a contract that never reaches the
                    // shipped image. Only `provides-file` carries it:
                    // reading a path, or overriding one, says nothing about
                    // how long it lives.
                    let build_only = match node
                        .entries()
                        .iter()
                        .find(|e| e.name().map(|n| n.value()) == Some("build-only"))
                    {
                        None => false,
                        Some(entry) if kind != "provides-file" => {
                            issues.push(
                                Issue::new(
                                    format!("`build-only` is not a `{kind}` property"),
                                    &file,
                                    &text,
                                )
                                .at(entry.span(), "only `provides-file` declares a lifetime"),
                            );
                            false
                        }
                        Some(entry) => match entry.value().as_bool() {
                            Some(value) => value,
                            None => {
                                issues.push(
                                    Issue::new(
                                        format!("`build-only` takes #true or #false"),
                                        &file,
                                        &text,
                                    )
                                    .at(entry.span(), "not a boolean"),
                                );
                                false
                            }
                        },
                    };
                    for path in string_args(node) {
                        if !path.starts_with('/') {
                            issues.push(
                                Issue::new(
                                    format!("`{path}` is not an absolute path"),
                                    &file,
                                    &text,
                                )
                                .at(node.name().span(), "an exact path in the image"),
                            );
                        }
                        let decl = Decl {
                            name: path.to_string(),
                            span: node.name().span(),
                        };
                        match kind {
                            "provides-file" => {
                                if build_only {
                                    module.provides_files_build_only.push(path.to_string());
                                }
                                module.provides_files.push(decl);
                            }
                            "requires-file" => module.requires_files.push(decl),
                            _ => module.overrides.push(decl),
                        }
                    }
                }
                kind @ ("secret" | "arg") => {
                    let names = string_args(node);
                    if names.is_empty() {
                        issues.push(
                            Issue::new(format!("`{kind}` needs a name"), &file, &text)
                                .at(node.name().span(), "nothing named"),
                        );
                    }
                    for name in names {
                        let decl = Decl {
                            name: name.to_string(),
                            span: node.name().span(),
                        };
                        if kind == "secret" {
                            module.secrets.push(decl);
                        } else {
                            module.args.push(decl);
                        }
                    }
                }
                "collects" => {
                    let collected = string_args(node).first().map(|s| s.to_string());
                    let into = prop(node, "into");
                    match (collected, into) {
                        (Some(collected), Some(into)) if into.starts_with('/') => {
                            module.collects.push(Collect {
                                file: collected,
                                into: into.to_string(),
                                span: node.name().span(),
                            })
                        }
                        (collected, into) => {
                            let missing = if collected.is_none() {
                                "the filename it collects"
                            } else if into.is_none() {
                                "into=, where the build puts them"
                            } else {
                                "an absolute into="
                            };
                            issues.push(
                                Issue::new(format!("`collects` needs {missing}"), &file, &text)
                                    .at(node.name().span(), "incomplete")
                                    .help("`collects \"justfile.inc\" into=\"/usr/share/goojust/justfile.apps\"`"),
                            );
                        }
                    }
                }
                "fragment" => {
                    if let Some(first) = fragment_span {
                        issues.push(
                            Issue::new("`fragment` is declared twice", &file, &text)
                                .at(first, "first here")
                                .at(node.name().span(), "and again here"),
                        );
                        continue;
                    }
                    fragment_span = Some(node.name().span());
                    if !dir.join("Containerfile.inc").is_file() {
                        issues.push(
                            Issue::new(
                                format!("`{}` declares `fragment` but ships no Containerfile.inc", entry.path),
                                &file,
                                &text,
                            )
                            .at(node.name().span(), "nothing to place")
                            .help("shipping the file is what adds a fragment; this node only says where it goes"),
                        );
                    }
                    module.parse_fragment(node, &file, &text, issues);
                }
                "option" => {
                    if let Some(opt) = options::parse_option(node, &file, &text, issues) {
                        if module.options.iter().any(|o| o.name == opt.name) {
                            issues.push(
                                Issue::new(
                                    format!("option `{}` is declared twice", opt.name),
                                    &file,
                                    &text,
                                )
                                .at(opt.span, "already declared above"),
                            );
                        } else {
                            module.options.push(opt);
                        }
                    }
                }
                "asset" => {
                    if let Some(pin) = asset::parse(node, &file, &text, issues) {
                        if module.assets.iter().any(|a| a.name == pin.name) {
                            issues.push(
                                Issue::new(
                                    format!("asset `{}` is declared twice", pin.name),
                                    &file,
                                    &text,
                                )
                                .at(pin.span, "already declared above")
                                .help("two assets under one name would resolve to the same ASSET_* env"),
                            );
                        } else {
                            module.assets.push(pin);
                        }
                    }
                }
                "variant" => {
                    if let Some(variant) = options::parse_variant(node, &file, &text, issues) {
                        if module.variants.iter().any(|v| v.name == variant.name) {
                            issues.push(
                                Issue::new(
                                    format!("variant `{}` is declared twice", variant.name),
                                    &file,
                                    &text,
                                )
                                .at(variant.span, "already declared above"),
                            );
                        } else {
                            module.variants.push(variant);
                        }
                    }
                }
                "packages" => module.parse_packages(node, &file, &text, issues),
                other => issues.push(
                    Issue::new(format!("unknown node `{other}`"), &file, &text)
                        .at(node.name().span(), "not part of the schema")
                        .help("modules/SCHEMA.md documents every node a manifest may hold"),
                ),
            }
        }

        if module.description.is_empty() {
            issues.push(
                Issue::new(format!("`{}` declares no description", entry.path), &file, &text)
                    .help("one line, present tense, no trailing period; it names the module in the resolved build summary"),
            );
        }
        // A fragment adds to the generated block, so declaring these
        // alongside one is fine: they land on the block it adds to.
        // Dropping that block leaves them nowhere to go, which is worse
        // than not declaring them, so it is an error rather than a
        // silent omission.
        if !module.standard_layer {
            let dropped = module
                .secrets
                .iter()
                .map(|d| ("secret", d.name.as_str(), d.span))
                .chain(module.args.iter().map(|d| ("arg", d.name.as_str(), d.span)))
                .chain(
                    module
                        .options
                        .iter()
                        .map(|o| ("option", o.name.as_str(), o.span)),
                )
                .chain(
                    module
                        .assets
                        .iter()
                        .map(|a| ("asset", a.name.as_str(), a.span)),
                );
            for (kind, name, span) in dropped {
                issues.push(
                    Issue::new(
                        format!(
                            "`{}` declares `{kind} \"{name}\"` with no standard layer to carry it",
                            entry.path
                        ),
                        &file,
                        &text,
                    )
                    .at(span, "nowhere to land")
                    .help("`standard-layer #false` makes the fragment the whole layer, so it has to spell out its own mounts, args and env; drop one or the other"),
                );
            }
        }

        if module.supports.is_empty() {
            issues.push(
                Issue::new(format!("`{}` declares no `supports`", entry.path), &file, &text)
                    .help("a module has to say which base families it can build on, so a portability gap surfaces at lint rather than mid-build"),
            );
        }

        // A `repo` file is sourced by run-module.sh, which the generated
        // install runs before, so declared packages would be fetched from
        // a repo that does not exist yet. Refused rather than reordered:
        // the declaration is additive, so a module that needs its own repo
        // loses nothing by installing in module.sh, where the repo is
        // already configured.
        if dir.join("repo").is_file() {
            for group in &module.packages {
                issues.push(
                    Issue::new(
                        format!("`{}` declares both a `repo` file and `packages`", entry.path),
                        &file,
                        &text,
                    )
                    .at(group.span, "installed before the repo file is sourced")
                    .help("run-module.sh sources `repo` after the generated install, so call `dnf5 install -y` in module.sh instead"),
                );
            }
        }

        module.resolved = options::resolve(
            &module.options,
            &module.variants,
            &file,
            &text,
            entry,
            list,
            issues,
        );

        Some(module)
    }

    /// `fragment position="after" standard-layer=#false`
    ///
    /// Defaults are the additive case: the fragment goes above the
    /// generated block and the block is still emitted. `standard-layer
    /// #false` is how the full override the generator used to do
    /// implicitly is now asked for.
    fn parse_fragment(&mut self, node: &KdlNode, file: &str, text: &str, issues: &mut Issues) {
        let mut position_span = None;
        for prop in node.entries() {
            let Some(key) = prop.name().map(|n| n.value()) else {
                issues.push(
                    Issue::new("`fragment` takes no arguments", file, text)
                        .at(prop.span(), "unexpected value")
                        .help("`fragment position=\"after\"`"),
                );
                continue;
            };
            match key {
                "position" => match prop.value().as_string() {
                    Some(p @ ("before" | "after")) => {
                        self.fragment_after = p == "after";
                        position_span = Some(prop.span());
                    }
                    _ => issues.push(
                        Issue::new("`position` must be \"before\" or \"after\"", file, text)
                            .at(prop.span(), "not a position")
                            .help("before, the default, puts the fragment above the generated block; after puts it below"),
                    ),
                },
                "standard-layer" => match prop.value().as_bool() {
                    Some(v) => self.standard_layer = v,
                    None => issues.push(
                        Issue::new("`standard-layer` must be #true or #false", file, text)
                            .at(prop.span(), "not a boolean"),
                    ),
                },
                other => issues.push(
                    Issue::new(format!("unknown fragment property `{other}`"), file, text)
                        .at(prop.span(), "not part of the schema")
                        .help("a fragment accepts `position` and `standard-layer`"),
                ),
            }
        }

        if !self.standard_layer {
            if let Some(span) = position_span {
                issues.push(
                    Issue::new(
                        "`position` says nothing without a standard layer",
                        file,
                        text,
                    )
                    .at(span, "there is nothing to be before or after")
                    .help("`standard-layer #false` makes the fragment the only thing this module emits"),
                );
            }
        }
    }

    /// `packages { fedora "pkg1" "pkg2" }`
    ///
    /// Each child node names a base family and carries the package names
    /// as positional arguments. An optional `enablerepo` property lets a
    /// module install from a repo that was added disabled.
    fn parse_packages(&mut self, node: &KdlNode, file: &str, text: &str, issues: &mut Issues) {
        let Some(children) = node.children() else {
            return;
        };
        for child in children.nodes() {
            let family = child.name().value().to_string();
            if family.is_empty() {
                issues.push(
                    Issue::new("a family name is required inside `packages`", file, text)
                        .at(child.name().span(), "empty name")
                        .help("`packages { fedora \"pkg1\" \"pkg2\" }`"),
                );
                continue;
            }
            // Checked rather than taken as given, because the renderer
            // emits only the family being built: a typo here would not
            // fail, it would install nothing and leave the module's own
            // script to discover the missing binary.
            if !FAMILIES.contains(&family.as_str()) {
                issues.push(
                    Issue::new(format!("unknown base family `{family}`"), file, text)
                        .at(child.name().span(), "not a family this repository builds on")
                        .help(format!("known families: {}", FAMILIES.join(", "))),
                );
                continue;
            }
            let mut packages: Vec<String> = Vec::new();
            for arg in child.entries().iter().filter(|e| e.name().is_none()) {
                // A bare 7 or #true parses fine and used to vanish here,
                // so the module installed one package fewer than it reads
                // as declaring.
                let Some(value) = arg.value().as_string() else {
                    issues.push(
                        Issue::new("a package name has to be a string", file, text)
                            .at(arg.span(), "not a string")
                            .help("quote it: `fedora \"7zip\"`"),
                    );
                    continue;
                };
                if let Some(problem) = bad_token(value) {
                    issues.push(
                        Issue::new(format!("package name `{value}` {problem}"), file, text)
                            .at(arg.span(), "would not survive the RUN line")
                            .help(TOKEN_HELP),
                    );
                    continue;
                }
                packages.push(value.to_string());
            }
            if packages.is_empty() {
                issues.push(
                    Issue::new(
                        format!("`{family}` has no packages listed"),
                        file,
                        text,
                    )
                    .at(child.name().span(), "nothing to install"),
                );
                continue;
            }
            let mut enablerepo: Option<String> = None;
            for entry in child.entries() {
                let Some(key) = entry.name().map(|n| n.value()) else {
                    continue;
                };
                match key {
                    "enablerepo" => match entry.value().as_string() {
                        Some(v) if !v.is_empty() => match bad_token(v) {
                            Some(problem) => issues.push(
                                Issue::new(format!("repo ID `{v}` {problem}"), file, text)
                                    .at(entry.span(), "would not survive the RUN line")
                                    .help(TOKEN_HELP),
                            ),
                            None => enablerepo = Some(v.to_string()),
                        },
                        _ => issues.push(
                            Issue::new("`enablerepo` needs a repo ID string", file, text)
                                .at(entry.span(), "not a string"),
                        ),
                    },
                    other => issues.push(
                        Issue::new(
                            format!("unknown property `{other}` in packages block"),
                            file,
                            text,
                        )
                        .at(entry.span(), "not part of the schema")
                        .help("a family entry in `packages` accepts `enablerepo`"),
                    ),
                }
            }
            self.packages.push(PackageGroup {
                family,
                packages,
                enablerepo,
                span: child.name().span(),
            });
        }
    }
}

/// Every module on disk, whether or not the list enables it. Scanned so
/// that an unsatisfied requirement can name the module that would fix it
/// rather than just reporting that nothing satisfies it.
fn providers_on_disk(root: &Path) -> BTreeMap<String, Vec<String>> {
    let mut out: BTreeMap<String, Vec<String>> = BTreeMap::new();
    let modules = root.join("modules");
    let mut dirs = vec![modules.clone()];
    while let Some(dir) = dirs.pop() {
        let Ok(entries) = std::fs::read_dir(&dir) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if !path.is_dir() {
                continue;
            }
            // The template is a copy-me reference, never a provider.
            if path.file_name().is_some_and(|n| n == "_template") {
                continue;
            }
            let manifest = path.join("module.kdl");
            if manifest.is_file() {
                let Ok(text) = std::fs::read_to_string(&manifest) else {
                    continue;
                };
                let Ok(doc) = text.parse::<KdlDocument>() else {
                    continue;
                };
                let name = path
                    .strip_prefix(&modules)
                    .unwrap_or(&path)
                    .display()
                    .to_string();
                for node in doc.nodes() {
                    if matches!(node.name().value(), "provides" | "provides-file") {
                        for cap in string_args(node) {
                            out.entry(cap.to_string()).or_default().push(name.clone());
                        }
                    }
                }
            } else {
                dirs.push(path);
            }
        }
    }
    out
}

/// Single pass over the resolved graph. No fixpoint evaluation, no merge
/// priorities, and nothing is ever auto-included: an unsatisfied
/// requirement names what would fix it and stops, so the list stays the
/// complete statement of what is in the image.
pub fn check_graph(modules: &[Module], list: &List, root: &Path, issues: &mut Issues) {
    // What each capability is offered by. Position no longer matters
    // here: a requirement is an edge in the sort, so a provider is
    // already above everything that needs it.
    let mut offered: BTreeMap<&str, Vec<&Module>> = BTreeMap::new();
    for module in modules {
        for decl in module.provides.iter().chain(module.provides_files.iter()) {
            offered.entry(decl.name.as_str()).or_default().push(module);
        }
    }

    // What the base itself satisfies, read off the node rather than held
    // as a constant here. A module requiring one of these depends on a
    // mechanism that is not portable across distros; a second base family
    // would declare its own substitutes, or declare none and let the
    // requirement fail loudly.
    //
    // Kept separate from `offered` rather than seeded into it, which is
    // what the constant did. Seeding happened after the module pass, so a
    // module declaring one of these names landed in the same entry and
    // read as the sole provider: it shadowed the base silently, with no
    // duplicate-provider warning, because the entry the base had put there
    // was empty and the count never reached two.
    let base_caps: BTreeMap<&str, &crate::list::Decl> = list
        .base
        .iter()
        .flat_map(|b| b.provides.iter().chain(b.provides_files.iter()))
        .map(|decl| (decl.name.as_str(), decl))
        .collect();

    for cap in base_caps.keys() {
        let Some(providers) = offered.get(cap) else {
            continue;
        };
        for module in providers {
            issues.push(
                Issue::new(
                    format!(
                        "`{}` provides `{cap}`, which the base image already provides",
                        module.path
                    ),
                    &module.file,
                    &module.text,
                )
                .at(
                    module
                        .provides
                        .iter()
                        .chain(module.provides_files.iter())
                        .find(|d| &d.name == cap)
                        .map(|d| d.span)
                        .unwrap_or_else(|| (0usize, 0usize).into()),
                    "already provided by the base",
                )
                .help(format!(
                    "the `base` node in {} declares it. Drop it from the module, or drop it from the base if the base no longer carries it",
                    list.file
                )),
            );
        }
    }

    // Every enabled module must support the base family it is building
    // against, so a portability gap surfaces at lint rather than mid-build.
    // Skipped entirely when the base names no family: that is already
    // reported on the node itself, and checking against an empty name
    // would blame forty modules for one missing line.
    let base_family = list
        .base
        .as_ref()
        .map(|b| b.family.as_str())
        .filter(|f| !f.is_empty());
    for module in modules {
        let Some(base_family) = base_family else { break };
        if !module.supports.iter().any(|f| f == base_family) {
            let supported = module.supports.join(", ");
            issues.push(
                Issue::new(
                    format!(
                        "`{}` does not support the `{base_family}` base family",
                        module.path
                    ),
                    &module.file,
                    &module.text,
                )
                .help(if supported.is_empty() {
                    "add `supports \"fedora\"` to the manifest".to_string()
                } else {
                    format!("it declares support for: {supported}")
                }),
            );
        }
    }

    for (capability, providers) in &offered {
        if providers.len() > 1 {
            let names: Vec<&str> = providers.iter().map(|m| m.path.as_str()).collect();
            let first = providers[0];
            issues.push(
                Issue::new(
                    format!("`{capability}` is provided by more than one enabled module"),
                    &first.file,
                    &first.text,
                )
                .at(
                    first.provides.iter().chain(first.provides_files.iter())
                        .find(|d| d.name == **capability)
                        .map(|d| d.span)
                        .unwrap_or_else(|| (0usize, 0usize).into()),
                    "also provided elsewhere",
                )
                .help(format!(
                    "provided by: {}. Enable one provider, so that what satisfies a requirement is never ambiguous",
                    names.join(", ")
                )),
            );
        }
    }

    // Shipping SELinux policy is a claim on the base, not on another
    // module: lib/run-module.sh compiles every selinux/*.te with the base
    // image's toolchain and installs it into the base image's policy
    // store. Declaring it keeps the dependency visible in the manifest
    // rather than implied by a directory listing, and makes delisting
    // `mac-policy` from the base fail here instead of mid-build.
    const MAC_POLICY: &str = "mac-policy";
    for module in modules {
        // `dir`, not `path`: an out-of-tree module's files are under the
        // fetch directory, so looking under its list path would find no
        // selinux/ and quietly pass every remote module.
        let dir = root.join("modules").join(&module.dir);
        let has_policy = std::fs::read_dir(dir.join("selinux"))
            .into_iter()
            .flatten()
            .flatten()
            .any(|e| e.path().extension().is_some_and(|ext| ext == "te"));
        if !has_policy || module.requires.iter().any(|d| d.name == MAC_POLICY) {
            continue;
        }
        issues.push(
            Issue::new(
                format!(
                    "`{}` ships SELinux policy without requiring `{MAC_POLICY}`",
                    module.path
                ),
                &module.file,
                &module.text,
            )
            .help(format!(
                "add `requires \"{MAC_POLICY}\"`; lib/run-module.sh compiles selinux/*.te against the base image's policy store"
            )),
        );
    }

    let on_disk = providers_on_disk(root);

    for module in modules {
        let hard = module
            .requires
            .iter()
            .map(|d| (d, "requires"))
            .chain(module.requires_files.iter().map(|d| (d, "requires-file")));

        for (decl, kind) in hard {
            // The base satisfies it outright, and has no flavor to be
            // gated to, so neither check below applies.
            if base_caps.contains_key(decl.name.as_str()) {
                continue;
            }

            let Some(providers) = offered.get(decl.name.as_str()) else {
                let help = match on_disk.get(&decl.name) {
                    Some(candidates) => format!(
                        "{} would satisfy it; add it to image.kdl. Nothing is included automatically, so the list stays the complete statement of what is in the image",
                        candidates.join(" or ")
                    ),
                    None => format!(
                        "no module in the repository declares `provides {:?}`, and neither does the `base` node in {}",
                        decl.name, list.file
                    ),
                };
                issues.push(
                    Issue::new(
                        format!(
                            "`{}` {kind} `{}`, which nothing enabled provides",
                            module.path, decl.name
                        ),
                        &module.file,
                        &module.text,
                    )
                    .at(decl.span, "unsatisfied")
                    .help(help),
                );
                continue;
            };

            if let Some(provider) = providers.first() {
                // A gated provider only exists on its own flavor, so an
                // ungated consumer, or one gated elsewhere, would find it
                // missing on every other target.
                if let Some(provider_flavor) = &provider.flavor {
                    if module.flavor.as_ref() != Some(provider_flavor) {
                        issues.push(
                            Issue::new(
                                format!(
                                    "`{}` {kind} `{}`, which only `{}` provides and only on the `{provider_flavor}` flavor",
                                    module.path, decl.name, provider.path
                                ),
                                &module.file,
                                &module.text,
                            )
                            .at(decl.span, "unsatisfied on every other target")
                            .help("either gate this module to the same flavor, or move the provider out of the flavor block"),
                        );
                    }
                }
            }
        }
    }
}

/// Every `collects` declared anywhere on disk, as filename to the module
/// that declares it, so a contribution whose consumer is not in the list
/// can name what to enable rather than just being dropped.
fn collectors_on_disk(root: &Path) -> BTreeMap<String, String> {
    let mut out = BTreeMap::new();
    let modules = root.join("modules");
    let mut dirs = vec![modules.clone()];
    while let Some(dir) = dirs.pop() {
        let Ok(entries) = std::fs::read_dir(&dir) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if !path.is_dir() || path.file_name().is_some_and(|n| n == "_template") {
                continue;
            }
            let manifest = path.join("module.kdl");
            if !manifest.is_file() {
                dirs.push(path);
                continue;
            }
            let Ok(text) = std::fs::read_to_string(&manifest) else {
                continue;
            };
            let Ok(doc) = text.parse::<KdlDocument>() else {
                continue;
            };
            let name = path
                .strip_prefix(&modules)
                .unwrap_or(&path)
                .display()
                .to_string();
            for node in doc
                .nodes()
                .iter()
                .filter(|n| n.name().value() == "collects")
            {
                if let Some(file) = string_args(node).first() {
                    out.insert(file.to_string(), name.clone());
                }
            }
        }
    }
    out
}

/// Which files each module contributes, and where the build puts each.
/// Resolved on the host so the runner carries no path of its own and any
/// module can start collecting a new filename without it being taught
/// about one.
pub fn resolve_collects(
    modules: &[Module],
    root: &Path,
    issues: &mut Issues,
) -> BTreeMap<String, Vec<(String, String)>> {
    // One collector per filename: two would make where a contribution
    // goes depend on module list order.
    let mut by_file: BTreeMap<&str, &Module> = BTreeMap::new();
    for module in modules {
        for collect in &module.collects {
            if let Some(first) = by_file.get(collect.file.as_str()) {
                issues.push(
                    Issue::new(
                        format!("two enabled modules collect `{}`", collect.file),
                        &module.file,
                        &module.text,
                    )
                    .at(collect.span, "collected again here")
                    .help(format!("already collected by `{}`", first.path)),
                );
            } else {
                by_file.insert(collect.file.as_str(), module);
            }
        }
    }

    let on_disk = collectors_on_disk(root);
    let mut out: BTreeMap<String, Vec<(String, String)>> = BTreeMap::new();

    for module in modules {
        let dir = root.join("modules").join(&module.dir);
        for (file, collector) in &on_disk {
            if !dir.join(file).is_file() {
                continue;
            }
            match by_file.get(file.as_str()) {
                Some(enabled) => {
                    let into = enabled
                        .collects
                        .iter()
                        .find(|c| &c.file == file)
                        .map(|c| c.into.clone())
                        .unwrap_or_default();
                    // The pairs reach the runner as env on the standard
                    // layer, so a module that dropped that layer would
                    // contribute nothing while looking like it does.
                    if !module.standard_layer {
                        issues.push(
                            Issue::new(
                                format!(
                                    "`{}` ships a {file} with no standard layer to collect it from",
                                    module.path
                                ),
                                &module.file,
                                &module.text,
                            )
                            .help(format!(
                                "`standard-layer #false` makes the fragment the whole layer, so it has to append the file to {into} itself"
                            )),
                        );
                        continue;
                    }
                    out.entry(module.path.clone())
                        .or_default()
                        .push((file.clone(), into));
                }
                // The file would be silently ignored, which is how a
                // contribution goes missing with nothing failing.
                None => issues.push(
                    Issue::new(
                        format!(
                            "`{}` ships a {file} but nothing enabled collects it",
                            module.path
                        ),
                        &module.file,
                        &module.text,
                    )
                    .help(format!(
                        "`{collector}` collects it; add it to image.kdl, or drop the {file}"
                    )),
                ),
            }
        }
    }
    out
}
