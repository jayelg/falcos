//! image.kdl: the image author's file.
//!
//! Which modules are in the image, in what order, gated to which flavors,
//! with which options set. Everything a module must not decide for itself.

use crate::diag::{Issue, Issues};
use crate::remote::{self, Remote, REMOTE_DIR};
use kdl::{KdlDocument, KdlNode, KdlValue};
use miette::SourceSpan;

/// The build target that carries no flavor: the ungated set, published
/// unsuffixed. A reserved token rather than a flavor, because a cache tag
/// and a matrix entry both need a spellable name, and because calling it a
/// flavor would reintroduce the hand-maintained device-neutral alias that
/// declaring it this way exists to avoid.
pub const NO_FLAVOR: &str = "none";

/// The base image, and what building on it may assume.
///
/// Declared rather than derived. The family used to be recovered by
/// looking for the string "fedora" in the `FROM` line, which could only
/// ever answer "fedora", and the capabilities the base provides were a
/// constant in the checker. Both are decisions about the image, so both
/// are made in the image author's file.
pub struct Base {
    /// The full image reference, emitted verbatim as the generated `FROM`.
    pub image: String,
    pub family: String,
    /// Capabilities the base satisfies that no module could implement
    /// portably: rechunking, initramfs generation, MAC policy.
    pub provides: Vec<Decl>,
    /// Binaries the base guarantees. They join the contract file paths the
    /// modules declare, and are checked the same way on the built image.
    pub provides_files: Vec<Decl>,
    pub span: SourceSpan,
}

/// A name the base declares, with the span to point at when something
/// about it is wrong.
pub struct Decl {
    pub name: String,
    pub span: SourceSpan,
}

pub struct Flavor {
    pub name: String,
    pub default: bool,
    pub pr_build: bool,
    pub span: SourceSpan,
}

/// One entry in the list: a module, and the decisions the image author
/// makes about it.
pub struct Entry {
    pub path: String,
    pub flavor: Option<String>,
    pub variant: Option<String>,
    /// Option name to the values set on it. Checked against what the
    /// module declares, not here: what a module accepts is not something
    /// this file can know.
    pub options: Vec<(String, Vec<KdlValue>, SourceSpan)>,
    /// The pin, for a module that lives outside this repository. Absent
    /// means in tree, which is why nothing about an existing entry
    /// changes.
    pub remote: Option<Remote>,
    pub span: SourceSpan,
}

impl Entry {
    /// Where the module's directory is, relative to `modules/`. The same
    /// as its list path in tree; under the fetch directory when it is
    /// pinned from elsewhere, so the mount in the generated Containerfile
    /// says which one a layer is built from.
    pub fn dir(&self) -> String {
        match self.remote {
            Some(_) => format!("{REMOTE_DIR}/{}", self.path),
            None => self.path.clone(),
        }
    }
}

pub struct List {
    pub file: String,
    pub text: String,
    /// None only when the `base` node is missing or malformed, which is
    /// already an issue: nothing downstream invents a default for it.
    pub base: Option<Base>,
    pub flavors: Vec<Flavor>,
    pub entries: Vec<Entry>,
}

fn is_flavor_name(name: &str) -> bool {
    let mut chars = name.chars();
    match chars.next() {
        Some(c) if c.is_ascii_lowercase() => {}
        _ => return false,
    }
    chars.all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-')
}

/// The first unnamed entry of a node, as a string.
fn string_arg(node: &KdlNode) -> Option<&str> {
    node.entries()
        .iter()
        .find(|e| e.name().is_none())
        .and_then(|e| e.value().as_string())
}

/// Every unnamed entry of a node, as strings, so `provides "a" "b"` reads
/// as the list it looks like.
fn string_args(node: &KdlNode) -> Vec<&str> {
    node.entries()
        .iter()
        .filter(|e| e.name().is_none())
        .filter_map(|e| e.value().as_string())
        .collect()
}

impl List {
    pub fn load(path: &str) -> Result<(Self, Issues), Box<Issue>> {
        let text = std::fs::read_to_string(path)
            .map_err(|e| Box::new(Issue::new(format!("cannot read {path}: {e}"), path, "")))?;
        Ok(Self::parse(path, text))
    }

    pub fn parse(file: &str, text: String) -> (Self, Issues) {
        let mut issues = Issues::default();
        let mut list = List {
            file: file.to_string(),
            text: text.clone(),
            base: None,
            flavors: Vec::new(),
            entries: Vec::new(),
        };

        let doc: KdlDocument = match text.parse() {
            Ok(doc) => doc,
            Err(err) => {
                // kdl's own parse errors already carry spans and render
                // through the same reporter, so they are passed through
                // rather than restated.
                eprintln!("{:?}", miette::Report::new(err));
                issues.push(Issue::new(format!("{file} is not valid KDL"), file, &text));
                return (list, issues);
            }
        };

        for node in doc.nodes() {
            match node.name().value() {
                "base" => list.parse_base(node, &mut issues),
                "flavors" => list.parse_flavors(node, &mut issues),
                "modules" => list.parse_modules(node, &mut issues),
                other => issues.push(
                    Issue::new(format!("unknown top-level node `{other}`"), file, &text)
                        .at(node.name().span(), "not part of the schema")
                        .help(
                            "image.kdl holds a `base` node, an optional `flavors` block and a `modules` block",
                        ),
                ),
            }
        }

        if !doc.nodes().iter().any(|n| n.name().value() == "modules") {
            issues.push(
                Issue::new(format!("{file} has no `modules` block"), file, &text)
                    .help("an image with no modules is almost certainly a mistake; the block is required even when empty"),
            );
        }

        // Required, with no default: the generated `FROM` comes from it,
        // and so does the family every module's `supports` is checked
        // against. Inferring either was how a build could target something
        // nobody had declared.
        if list.base.is_none() && !doc.nodes().iter().any(|n| n.name().value() == "base") {
            issues.push(
                Issue::new(format!("{file} has no `base` node"), file, &text).help(
                    "`base \"quay.io/fedora/fedora-bootc:44\" { family \"fedora\" }`, \
                     naming the image every layer builds on",
                ),
            );
        }

        list.check_flavors(&mut issues);
        (list, issues)
    }

    fn parse_base(&mut self, node: &KdlNode, issues: &mut Issues) {
        let (file, text) = (self.file.clone(), self.text.clone());

        if let Some(first) = &self.base {
            issues.push(
                Issue::new("`base` is declared twice", &file, &text)
                    .at(first.span, "first here")
                    .at(node.name().span(), "and again here")
                    .help("an image builds on one base; a second family is a second image"),
            );
            return;
        }

        let Some(image) = string_arg(node) else {
            issues.push(
                Issue::new("`base` needs an image reference", &file, &text)
                    .at(node.name().span(), "no image given")
                    .help("`base \"quay.io/fedora/fedora-bootc:44\"`, emitted verbatim as the generated FROM"),
            );
            return;
        };

        let mut base = Base {
            image: image.to_string(),
            family: String::new(),
            provides: Vec::new(),
            provides_files: Vec::new(),
            span: node.name().span(),
        };

        for child in node.children().map(|c| c.nodes()).unwrap_or_default() {
            let names = || {
                string_args(child)
                    .iter()
                    .map(|name| Decl {
                        name: name.to_string(),
                        span: child.name().span(),
                    })
                    .collect::<Vec<_>>()
            };
            match child.name().value() {
                "family" => match string_arg(child) {
                    Some(f) => base.family = f.to_string(),
                    None => issues.push(
                        Issue::new("`family` needs a name", &file, &text)
                            .at(child.name().span(), "no family given")
                            .help("`family \"fedora\"`, matched against each module's `supports`"),
                    ),
                },
                "provides" => base.provides.extend(names()),
                "provides-file" => base.provides_files.extend(names()),
                other => issues.push(
                    Issue::new(format!("unknown base property `{other}`"), &file, &text)
                        .at(child.name().span(), "not part of the schema")
                        .help("a base accepts `family`, `provides` and `provides-file`"),
                ),
            }
        }

        if base.family.is_empty() {
            issues.push(
                Issue::new("`base` declares no `family`", &file, &text)
                    .at(base.span, "no family")
                    .help("every module declares which families it `supports`, and the two are checked against each other"),
            );
        }

        // A relative path is not a contract file the built image can be
        // checked for, and it would silently pass the existence test from
        // whatever directory the check happened to run in.
        for decl in &base.provides_files {
            if !decl.name.starts_with('/') {
                issues.push(
                    Issue::new(
                        format!("`{}` is not an absolute path", decl.name),
                        &file,
                        &text,
                    )
                    .at(decl.span, "`provides-file` takes absolute paths")
                    .help("the path is checked on the finished image, where nothing has a working directory"),
                );
            }
        }

        self.base = Some(base);
    }

    fn parse_flavors(&mut self, block: &KdlNode, issues: &mut Issues) {
        let (file, text) = (self.file.clone(), self.text.clone());
        let Some(children) = block.children() else {
            issues.push(
                Issue::new("`flavors` has no flavors in it", &file, &text)
                    .at(block.name().span(), "empty block")
                    .help("omit the block entirely to build one unnamed image"),
            );
            return;
        };

        for node in children.nodes() {
            let name = node.name().value().to_string();
            let mut flavor = Flavor {
                default: false,
                pr_build: false,
                span: node.name().span(),
                name,
            };

            if !is_flavor_name(&flavor.name) {
                issues.push(
                    Issue::new(format!("invalid flavor name `{}`", flavor.name), &file, &text)
                        .at(flavor.span, "must be lowercase letters, digits and dashes, starting with a letter")
                        .help("a flavor name reaches an image name, a cache tag and a build arg, all of which restrict it"),
                );
            } else if flavor.name == NO_FLAVOR {
                issues.push(
                    Issue::new(format!("`{NO_FLAVOR}` is reserved"), &file, &text)
                        .at(flavor.span, "not usable as a flavor name")
                        .help("`none` names the ungated build, which is published unsuffixed and needs no declaration"),
                );
            }

            for entry in node.entries() {
                let Some(key) = entry.name().map(|n| n.value()) else {
                    issues.push(
                        Issue::new("a flavor takes no arguments", &file, &text)
                            .at(entry.span(), "unexpected value")
                            .help("the flavor's name is the node name: `desktop default=#true`"),
                    );
                    continue;
                };
                let flag = |issues: &mut Issues| match entry.value().as_bool() {
                    Some(v) => v,
                    None => {
                        issues.push(
                            Issue::new(format!("`{key}` must be #true or #false"), &file, &text)
                                .at(entry.span(), "not a boolean"),
                        );
                        false
                    }
                };
                match key {
                    "default" => flavor.default = flag(issues),
                    "pr-build" => flavor.pr_build = flag(issues),
                    other => issues.push(
                        Issue::new(format!("unknown flavor property `{other}`"), &file, &text)
                            .at(entry.span(), "not part of the schema")
                            .help("a flavor accepts `default` and `pr-build`"),
                    ),
                }
            }

            if let Some(dup) = self.flavors.iter().find(|f| f.name == flavor.name) {
                issues.push(
                    Issue::new(
                        format!("flavor `{}` is declared twice", flavor.name),
                        &file,
                        &text,
                    )
                    .at(dup.span, "first here")
                    .at(flavor.span, "and again here"),
                );
                continue;
            }
            self.flavors.push(flavor);
        }
    }

    fn parse_modules(&mut self, block: &KdlNode, issues: &mut Issues) {
        let (file, text) = (self.file.clone(), self.text.clone());
        let Some(children) = block.children() else {
            return;
        };
        for node in children.nodes() {
            match node.name().value() {
                "module" => {
                    if let Some(entry) = self.parse_entry(node, None, issues) {
                        self.entries.push(entry);
                    }
                }
                "flavor" => {
                    let Some(name) = string_arg(node) else {
                        issues.push(
                            Issue::new("`flavor` needs a flavor name", &file, &text)
                                .at(node.name().span(), "no name given")
                                .help("`flavor \"desktop\" { module \"...\" }`"),
                        );
                        continue;
                    };
                    let name = name.to_string();
                    if !self.flavors.iter().any(|f| f.name == name) {
                        let known: Vec<&str> =
                            self.flavors.iter().map(|f| f.name.as_str()).collect();
                        issues.push(
                            Issue::new(format!("`{name}` is not a declared flavor"), &file, &text)
                                .at(node.name().span(), "no such flavor")
                                .help(if known.is_empty() {
                                    "no flavors are declared; add a `flavors` block above"
                                        .to_string()
                                } else {
                                    format!("declared flavors: {}", known.join(", "))
                                }),
                        );
                    }
                    for inner in node.children().map(|c| c.nodes()).unwrap_or_default() {
                        if inner.name().value() != "module" {
                            issues.push(
                                Issue::new(
                                    format!("`{}` is not allowed inside a flavor block", inner.name().value()),
                                    &file,
                                    &text,
                                )
                                .at(inner.name().span(), "only `module` belongs here")
                                .help("flavor blocks do not nest; a module gated to two flavors is listed under each"),
                            );
                            continue;
                        }
                        if let Some(entry) = self.parse_entry(inner, Some(name.clone()), issues) {
                            self.entries.push(entry);
                        }
                    }
                }
                other => issues.push(
                    Issue::new(format!("unknown node `{other}` in `modules`"), &file, &text)
                        .at(node.name().span(), "not part of the schema")
                        .help("`modules` holds `module` entries and `flavor` blocks"),
                ),
            }
        }
    }

    fn parse_entry(
        &self,
        node: &KdlNode,
        flavor: Option<String>,
        issues: &mut Issues,
    ) -> Option<Entry> {
        let (file, text) = (&self.file, &self.text);
        let Some(path) = string_arg(node) else {
            issues.push(
                Issue::new("`module` needs a path", file, text)
                    .at(node.name().span(), "no path given")
                    .help("`module \"core/flatpak\"`, the path relative to modules/"),
            );
            return None;
        };
        let path = path.to_string();

        if let Some(dup) = self
            .entries
            .iter()
            .find(|e| e.path == path && e.flavor == flavor)
        {
            issues.push(
                Issue::new(format!("`{path}` is listed twice"), file, text)
                    .at(dup.span, "first here")
                    .at(node.name().span(), "and again here")
                    .help("a module builds once per flavor it is listed under"),
            );
            return None;
        }

        let mut variant = None;
        for entry in node.entries() {
            let Some(key) = entry.name().map(|n| n.value()) else {
                continue; // the path itself
            };
            match key {
                "variant" => match entry.value().as_string() {
                    Some(v) => variant = Some(v.to_string()),
                    None => issues.push(
                        Issue::new("`variant` must be a string", file, text)
                            .at(entry.span(), "not a string"),
                    ),
                },
                other => issues.push(
                    Issue::new(format!("unknown module property `{other}`"), file, text)
                        .at(entry.span(), "not part of the schema")
                        .help("a list entry accepts `variant`; options are set as child nodes"),
                ),
            }
        }

        // Every child is an option except the pin. Options are carried
        // unvalidated: what a module accepts is declared in its own
        // manifest, which is checked against these once both are loaded.
        let mut options = Vec::new();
        let mut pin: Option<Remote> = None;
        for child in node.children().map(|c| c.nodes()).unwrap_or_default() {
            if child.name().value() == "source" {
                if let Some(first) = pin.as_ref().map(|p| p.span) {
                    issues.push(
                        Issue::new(format!("`{path}` is pinned twice"), file, text)
                            .at(first, "first here")
                            .at(child.name().span(), "and again here"),
                    );
                    continue;
                }
                pin = remote::parse(child, file, text, issues);
                continue;
            }
            options.push((
                child.name().value().to_string(),
                child
                    .entries()
                    .iter()
                    .filter(|e| e.name().is_none())
                    .map(|e| e.value().clone())
                    .collect(),
                child.name().span(),
            ));
        }

        // A fetched module is one directory under the fetch root, so its
        // name is a single path segment. It is also the module's identity
        // in the summary, the finalize order and every diagnostic, which
        // is the other reason it is not free-form.
        if pin.is_some() && !is_flavor_name(&path) {
            issues.push(
                Issue::new(format!("invalid module name `{path}`"), file, text)
                    .at(node.name().span(), "must be lowercase letters, digits and dashes, starting with a letter")
                    .help(format!("a pinned module is fetched into modules/{REMOTE_DIR}/<name>, so its name is one path segment rather than a path")),
            );
        }

        Some(Entry {
            path,
            flavor,
            variant,
            options,
            remote: pin,
            span: node.name().span(),
        })
    }

    /// The marks that replaced "first entry in the list". Three unrelated
    /// policies had accumulated on that one positional accident, so each
    /// one that survives is declared and checked separately.
    fn check_flavors(&self, issues: &mut Issues) {
        let (file, text) = (&self.file, &self.text);
        if self.flavors.is_empty() {
            return;
        }

        let defaults: Vec<&Flavor> = self.flavors.iter().filter(|f| f.default).collect();
        match defaults.len() {
            1 => {}
            0 => issues.push(
                Issue::new("no flavor is marked `default=#true`", file, text)
                    .at(self.flavors[0].span, "one of these must be the default")
                    .help("`just build` with no flavor has to build something; marking it beats inferring it from position"),
            ),
            _ => {
                let mut issue = Issue::new("more than one flavor is marked `default=#true`", file, text);
                for f in &defaults {
                    issue = issue.at(f.span, "marked default");
                }
                issues.push(issue);
            }
        }

        let pr: Vec<&Flavor> = self.flavors.iter().filter(|f| f.pr_build).collect();
        if pr.len() > 1 {
            let mut issue = Issue::new(
                "more than one flavor is marked `pr-build=#true`",
                file,
                text,
            )
            .help("a pull request builds one flavor, for half the runner time");
            for f in &pr {
                issue = issue.at(f.span, "marked pr-build");
            }
            issues.push(issue);
        }
    }

    pub fn default_flavor(&self) -> Option<&str> {
        self.flavors
            .iter()
            .find(|f| f.default)
            .map(|f| f.name.as_str())
    }

    /// Falls back to the default: a repository that has not thought about
    /// which flavor covers the most build surface still gets a PR build.
    pub fn pr_flavor(&self) -> Option<&str> {
        self.flavors
            .iter()
            .find(|f| f.pr_build)
            .map(|f| f.name.as_str())
            .or_else(|| self.default_flavor())
    }

    /// Every flavor, plus the ungated set. The ungated set needs no
    /// declaration: it exists because the layers above `ARG FLAVOR` do.
    pub fn targets(&self) -> Vec<String> {
        let mut out = vec![NO_FLAVOR.to_string()];
        out.extend(self.flavors.iter().map(|f| f.name.clone()));
        out
    }
}
