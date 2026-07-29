//! modules.kdl: the image author's file.
//!
//! Which modules are in the image, in what order, gated to which flavors,
//! with which options set. Everything a module must not decide for itself.

use crate::diag::{Issue, Issues};
use kdl::{KdlDocument, KdlNode, KdlValue};
use miette::SourceSpan;

/// The build target that carries no flavor: the ungated set, published
/// unsuffixed. A reserved token rather than a flavor, because a cache tag
/// and a matrix entry both need a spellable name, and because calling it a
/// flavor would reintroduce the hand-maintained device-neutral alias that
/// declaring it this way exists to avoid.
pub const NO_FLAVOR: &str = "none";

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
    /// Option name to the values set on it. Accepted and carried here,
    /// but only meaningful once module manifests declare what each module
    /// takes: what a module accepts is not something this file can know.
    #[allow(dead_code)]
    pub options: Vec<(String, Vec<KdlValue>, SourceSpan)>,
    pub span: SourceSpan,
}

pub struct List {
    pub file: String,
    pub text: String,
    pub flavors: Vec<Flavor>,
    pub entries: Vec<Entry>,
}

/// Reserved for out-of-tree modules. Claimed now so that adding fetching
/// later is not a format change, and rejected until then so nobody writes
/// one expecting it to work.
const RESERVED: [&str; 3] = ["source", "ref", "sha256"];

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
                "flavors" => list.parse_flavors(node, &mut issues),
                "modules" => list.parse_modules(node, &mut issues),
                other => issues.push(
                    Issue::new(format!("unknown top-level node `{other}`"), file, &text)
                        .at(node.name().span(), "not part of the schema")
                        .help(
                            "modules.kdl holds an optional `flavors` block and a `modules` block",
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

        list.check_flavors(&mut issues);
        (list, issues)
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
            if RESERVED.contains(&key) {
                issues.push(
                    Issue::new(format!("`{key}` is reserved and not implemented"), file, text)
                        .at(entry.span(), "cannot be used yet")
                        .help("source, ref and sha256 are claimed for out-of-tree modules so that adding them later is not a format change"),
                );
                continue;
            }
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

        // Carried unvalidated: what a module accepts is declared in its own
        // manifest, which is checked against these once both are loaded.
        let options = node
            .children()
            .map(|c| c.nodes())
            .unwrap_or_default()
            .iter()
            .map(|opt| {
                (
                    opt.name().value().to_string(),
                    opt.entries()
                        .iter()
                        .filter(|e| e.name().is_none())
                        .map(|e| e.value().clone())
                        .collect(),
                    opt.name().span(),
                )
            })
            .collect();

        Some(Entry {
            path,
            flavor,
            variant,
            options,
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
