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

/// A build target: which image, and which flavor of it.
///
/// Spelled `<image>/<flavor>` wherever a person, a script or a workflow
/// names one, with `<image>/none` for the ungated build. Qualified always,
/// never a bare flavor: a flavor name only means anything inside the image
/// that declares it, and two images may well declare the same one.
///
/// The published image name is the other half of this and deliberately not
/// the same string: `<image>` for the ungated build and `<image>-<flavor>`
/// otherwise. scripts/targets.sh owns that mapping, because it is about
/// where an image is published rather than about what is being built.
pub struct Target {
    pub image: String,
    /// A declared flavor, or `NO_FLAVOR` for the ungated build. The token
    /// rather than an `Option`, because that is what the entry filters
    /// compare a gate against: `none` matches no gate and so selects the
    /// ungated set, where no target at all means every entry in the list.
    pub flavor: String,
}

impl Target {
    /// `<image>/<flavor>`. Nothing is inferred from a half: a bare name
    /// could be either half, and guessing which would be wrong in a
    /// repository with an image and a flavor sharing a name.
    pub fn parse(text: &str) -> Option<Self> {
        let (image, flavor) = text.split_once('/')?;
        if image.is_empty() || flavor.is_empty() || flavor.contains('/') {
            return None;
        }
        Some(Target {
            image: image.to_string(),
            flavor: flavor.to_string(),
        })
    }
}

impl std::fmt::Display for Target {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}/{}", self.image, self.flavor)
    }
}

/// One image: what it calls itself, what it builds on, and everything it
/// is made of.
///
/// The unit the repository is written in. A second image is a second one
/// of these, with its own base, its own flavors and its own module list,
/// and nothing here is shared with any other.
///
/// os-release is the carrier for the naming, so one declaration reaches
/// the GRUB entry titles ostree writes, the desktop about page, the
/// default hostname and the published image name. Where the image
/// publishes is not here: scripts/registry.sh derives that from the git
/// remote, so a fork follows its own.
///
/// Everything but the name is optional, and an undeclared field is empty
/// rather than guessed at: the branding helper owns the one default there
/// is, `<name> <version>`, and restating it here would be a second copy of
/// it.
pub struct Image {
    /// Where this was declared, and that file's source, so a diagnostic
    /// about anything under it points at the right file. Carried per image
    /// rather than per document because an image is a file.
    pub file: String,
    pub text: String,
    /// The machine name: published image, build target, cache tag,
    /// os-release DEFAULT_HOSTNAME, MOK key directory. Derived from `name`
    /// unless declared, and restricted like a flavor name because it
    /// becomes an image tag.
    pub id: String,
    pub name: String,
    pub pretty_name: String,
    pub url: String,
    pub issues_url: String,
    /// Repository-relative paths, under brand/, which is the only
    /// directory of theirs the build context carries.
    pub logo: String,
    pub watermark: String,
    /// None only when the `base` node is missing or malformed, which is
    /// already an issue: nothing downstream invents a default for it.
    pub base: Option<Base>,
    pub flavors: Vec<Flavor>,
    pub entries: Vec<Entry>,
    pub span: SourceSpan,
}

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

/// One workflow the image author has decided about, named by its file
/// stem under `.github/workflows/`.
///
/// A decision about the repository rather than about the image, which is
/// why nothing here reaches a build. It is in this file because a fork
/// that strips the module list down is the same fork that has no registry
/// to publish to, and both are the image author's to change without
/// editing anything that a rebase would overwrite.
pub struct WorkflowToggle {
    pub name: String,
    pub enabled: bool,
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
    /// Every image declared, in declaration order. Empty only when the
    /// `image` node is missing or malformed, which is already an issue: an
    /// image with no name is not one this can invent.
    pub images: Vec<Image>,
    /// Only the workflows named here. Silence means the workflow runs, so
    /// an absent block is the repository as it ships; `crate::workflow`
    /// reconciles this against what is actually on disk.
    pub workflows: Vec<WorkflowToggle>,
}

/// Lowercase letters, digits and dashes, starting with a letter. What a
/// flavor and the image id are both held to, because both reach an image
/// name and a cache tag, which restrict them the same way.
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
            images: Vec::new(),
            workflows: Vec::new(),
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
                "image" => list.parse_image(node, &mut issues),
                "workflows" => list.parse_workflows(node, &mut issues),
                other => issues.push(
                    Issue::new(format!("unknown top-level node `{other}`"), file, &text)
                        .at(node.name().span(), "not part of the schema")
                        .help(
                            "an image file holds one `image` node; `base`, `flavors` and \
                             `modules` are declared inside it, because they are what the \
                             image is rather than what the repository is",
                        ),
                ),
            }
        }

        // Required, with no default: every name the image answers to is
        // derived from it, and a build that guessed one would publish and
        // brand itself as something nobody declared.
        if !doc.nodes().iter().any(|n| n.name().value() == "image") {
            issues.push(
                Issue::new(format!("{file} declares no image"), file, &text).help(
                    "`image { name \"Name\" }`, what the image calls itself in os-release \
                     and what it publishes as",
                ),
            );
        }

        (list, issues)
    }

    fn parse_image(&mut self, node: &KdlNode, issues: &mut Issues) {
        let (file, text) = (self.file.clone(), self.text.clone());

        // The machine name used to be the node's argument. It is a labelled
        // child now, because there are three names in play — the file, the
        // machine name and the human one — and an unlabelled one in the
        // middle of them said nothing about which it was.
        if let Some(stray) = string_arg(node) {
            issues.push(
                Issue::new("`image` takes no argument", &file, &text)
                    .at(node.name().span(), "the name belongs in the block")
                    .help(format!(
                        "`image {{ id \"{stray}\" }}` is the machine name, and `name` is the \
                         human one it derives from when absent"
                    )),
            );
        }

        let mut image = Image {
            file: file.clone(),
            text: text.clone(),
            id: String::new(),
            name: String::new(),
            pretty_name: String::new(),
            url: String::new(),
            issues_url: String::new(),
            logo: String::new(),
            watermark: String::new(),
            base: None,
            flavors: Vec::new(),
            entries: Vec::new(),
            span: node.name().span(),
        };

        let children = node.children().map(|c| c.nodes()).unwrap_or_default();
        // Two passes, because the flavor set has to exist before the module
        // list can check a `flavor` block against it, and neither can be
        // required to come first in the file.
        for child in children {
            let value = |field: &str, issues: &mut Issues| match string_arg(child) {
                Some(v) => v.to_string(),
                None => {
                    issues.push(
                        Issue::new(format!("`{field}` needs a value"), &file, &text)
                            .at(child.name().span(), "nothing given"),
                    );
                    String::new()
                }
            };
            match child.name().value() {
                "id" => image.id = value("id", issues),
                "name" => image.name = value("name", issues),
                "pretty-name" => image.pretty_name = value("pretty-name", issues),
                "url" => image.url = value("url", issues),
                "issues-url" => image.issues_url = value("issues-url", issues),
                "logo" => image.logo = value("logo", issues),
                "watermark" => image.watermark = value("watermark", issues),
                "base" => image.parse_base(child, issues),
                "flavors" => image.parse_flavors(child, issues),
                "modules" => {}
                other => issues.push(
                    Issue::new(format!("unknown image property `{other}`"), &file, &text)
                        .at(child.name().span(), "not part of the schema")
                        .help(
                            "an image accepts `id`, `name`, `pretty-name`, `url`, \
                             `issues-url`, `logo` and `watermark`, and the `base`, \
                             `flavors` and `modules` blocks",
                        ),
                ),
            }
        }
        for child in children {
            if child.name().value() == "modules" {
                image.parse_modules(child, issues);
            }
        }

        if image.name.is_empty() {
            issues.push(
                Issue::new("`image` declares no `name`", &file, &text)
                    .at(image.span, "no name")
                    .help("`name \"Falcos\"` is os-release NAME, which the boot menu and the desktop read"),
            );
        }

        // Derived from the human name unless declared: an image called
        // Falcos publishes as falcos, and writing both down is two places
        // to change a name that has one meaning. Mechanical, and refused
        // rather than mangled when the result is not a legal image name,
        // because a silently rewritten name is one nobody can search for.
        if image.id.is_empty() {
            image.id = image.name.to_lowercase().replace(' ', "-");
            if !image.name.is_empty() && !is_flavor_name(&image.id) {
                issues.push(
                    Issue::new(
                        format!("`{}` does not derive a usable image name", image.name),
                        &file,
                        &text,
                    )
                    .at(image.span, "no `id`, and `name` does not lowercase into one")
                    .help("declare `id \"something\"`: lowercase letters, digits and dashes, starting with a letter"),
                );
                image.id = String::new();
            }
        } else if !is_flavor_name(&image.id) {
            issues.push(
                Issue::new(format!("invalid image name `{}`", image.id), &file, &text)
                    .at(image.span, "must be lowercase letters, digits and dashes, starting with a letter")
                    .help("it becomes an image tag, a cache tag and the default hostname, all of which restrict it"),
            );
        }

        // The build context carries brand/ and nothing else of theirs, so
        // a path outside it names a file no layer can open. Caught here
        // rather than as a missing file at build time, where the message
        // would be a copy failing three minutes in.
        for (field, path) in [("logo", &image.logo), ("watermark", &image.watermark)] {
            if !path.is_empty() && !path.starts_with("brand/") {
                issues.push(
                    Issue::new(format!("`{field}` is not under brand/"), &file, &text)
                        .at(image.span, "brand assets live in brand/")
                        .help("the build context carries brand/ for them; a path anywhere else is not in it"),
                );
            }
        }

        // Required, with no default: the generated `FROM` comes from it,
        // and so does the family every module's `supports` is checked
        // against. Inferring either was how a build could target something
        // nobody had declared.
        if image.base.is_none() && !children.iter().any(|c| c.name().value() == "base") {
            issues.push(
                Issue::new("`image` declares no `base`", &file, &text)
                    .at(image.span, "nothing to build on")
                    .help(
                        "`base \"quay.io/fedora/fedora-bootc:44\" { family \"fedora\" }`, \
                         naming the image every layer builds on",
                    ),
            );
        }

        if !children.iter().any(|c| c.name().value() == "modules") {
            issues.push(
                Issue::new("`image` has no `modules` block", &file, &text)
                    .at(image.span, "nothing in it")
                    .help("an image with no modules is almost certainly a mistake; the block is required even when empty"),
            );
        }

        image.check_flavors(issues);
        self.images.push(image);
    }

}

impl Image {
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

    /// `workflows { smoke-test enabled=#false }`
    ///
    /// Each child names a workflow by its file stem. Only the ones a fork
    /// has an opinion about are listed: whether the file exists is checked
    /// against the directory, in `crate::workflow`, because a name that
    /// matches nothing would otherwise be a line that quietly does
    /// nothing.
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

    /// Every image the repository declares, in declaration order.
    ///
    /// One, today, and the plural is the whole point: the generator emits
    /// a Containerfile per image, so it asks for the set rather than for
    /// the image. What the set is read out of is this type's business and
    /// changes without the generator noticing.
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

}

impl List {
    fn parse_workflows(&mut self, block: &KdlNode, issues: &mut Issues) {
        let (file, text) = (self.file.clone(), self.text.clone());
        let Some(children) = block.children() else {
            issues.push(
                Issue::new("`workflows` has no workflows in it", &file, &text)
                    .at(block.name().span(), "empty block")
                    .help("omit the block entirely; every workflow in .github/workflows/ runs unless something here says otherwise"),
            );
            return;
        };

        for node in children.nodes() {
            let name = node.name().value().to_string();
            let span = node.name().span();

            if let Some(dup) = self.workflows.iter().find(|w| w.name == name) {
                issues.push(
                    Issue::new(format!("workflow `{name}` is declared twice"), &file, &text)
                        .at(dup.span, "first here")
                        .at(span, "and again here")
                        .help("one workflow is either on or off; two answers means the file below wins silently"),
                );
                continue;
            }

            let mut enabled: Option<bool> = None;
            // Whether the property was written at all, which is a
            // different question from whether it parsed. `enabled="yes"`
            // is already reported as not a boolean, and adding "says
            // nothing about whether it runs" underneath it would be the
            // same mistake described twice.
            let mut stated = false;
            for entry in node.entries() {
                let Some(key) = entry.name().map(|n| n.value()) else {
                    issues.push(
                        Issue::new("a workflow takes no arguments", &file, &text)
                            .at(entry.span(), "unexpected value")
                            .help("the file stem is the node name: `smoke-test enabled=#false`"),
                    );
                    continue;
                };
                match key {
                    "enabled" => {
                        stated = true;
                        match entry.value().as_bool() {
                            Some(v) => enabled = Some(v),
                            None => issues.push(
                                Issue::new("`enabled` must be #true or #false", &file, &text)
                                    .at(entry.span(), "not a boolean"),
                            ),
                        }
                    }
                    other => issues.push(
                        Issue::new(format!("unknown workflow property `{other}`"), &file, &text)
                            .at(entry.span(), "not part of the schema")
                            .help("a workflow accepts `enabled`"),
                    ),
                }
            }

            // A bare name states nothing, so the reconciler would leave
            // the workflow exactly as it found it. Saying nothing about a
            // line somebody wrote on purpose is worse than refusing it.
            let Some(enabled) = enabled else {
                if !stated {
                    issues.push(
                        Issue::new(
                            format!("`{name}` says nothing about whether it runs"),
                            &file,
                            &text,
                        )
                        .at(span, "no `enabled`")
                        .help(format!(
                            "`{name} enabled=#false` turns it off; a workflow nobody wants to change belongs outside this block"
                        )),
                    );
                }
                continue;
            };

            self.workflows.push(WorkflowToggle {
                name,
                enabled,
                span,
            });
        }
    }

    pub fn images(&self) -> Vec<&Image> {
        self.images.iter().collect()
    }

    /// The image a command answers about when it is given no image, and
    /// the one a bare build builds. The only one there is until a second
    /// is declared.
    pub fn default_image(&self) -> Option<&Image> {
        self.images.first()
    }

    /// Every target: for each image, the ungated set and then its
    /// flavors. The ungated set needs no declaration: it exists because
    /// the layers above `ARG FLAVOR` do.
    pub fn targets(&self) -> Vec<Target> {
        let mut out = Vec::new();
        for image in self.images() {
            out.push(Target {
                image: image.id.clone(),
                flavor: NO_FLAVOR.to_string(),
            });
            out.extend(image.flavors.iter().map(|f| Target {
                image: image.id.clone(),
                flavor: f.name.clone(),
            }));
        }
        out
    }

    /// What a build with nothing named builds: the default image, at its
    /// default flavor, or its ungated set when it declares no flavors.
    ///
    /// An image with no flavors used to answer nothing here, which left
    /// `scripts/build.sh` validating the empty string against the target
    /// list and dying on it. The ungated set is buildable whether or not
    /// any flavor exists, so it is what a repository that declares none
    /// gets.
    pub fn default_target(&self) -> Option<Target> {
        self.default_image().map(|image| Target {
            image: image.id.clone(),
            flavor: image.default_flavor().unwrap_or(NO_FLAVOR).to_string(),
        })
    }

    /// The one target a pull request builds, for half the runner time.
    pub fn pr_target(&self) -> Option<Target> {
        self.default_image().map(|image| Target {
            image: image.id.clone(),
            flavor: image.pr_flavor().unwrap_or(NO_FLAVOR).to_string(),
        })
    }
}
