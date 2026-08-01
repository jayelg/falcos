//! Which workflows run.
//!
//! The declaration in image.kdl reconciled against `.github/workflows/`,
//! for a fork that wants the weekly smoke test off or has no registry to
//! publish to. Reconciled through the GitHub API, never by rewriting the
//! files: GITHUB_TOKEN cannot push a change under that path, so anything
//! that edited a workflow would need a PAT or an App, and a template user
//! would have to provision a secret before their fork worked at all. The
//! API does the same job with `actions: write` and leaves no commit.
//!
//! Nothing here reaches a build, which is why the generated Containerfile
//! does not change when a toggle does. The committed Containerfile earns
//! its drift check by being what the build consumes; a workflow is not.

use crate::diag::{Issue, Issues};
use crate::list::List;
use std::fmt::Write as _;
use std::path::Path;

/// GitHub's path, not this repository's choice, which is why it is
/// written here rather than declared anywhere.
const WORKFLOW_DIR: &str = ".github/workflows";

/// Every workflow file and whether the declaration says it runs.
///
/// Every file, not only the declared ones. The reconciler has to be able
/// to turn a workflow back on after somebody switched it off in the web
/// UI, and it can only do that if it is told the declared state of a
/// workflow nobody has mentioned. Undeclared is enabled: a fork that has
/// not thought about this gets the repository as it ships.
pub fn resolve(list: &List, root: &Path, issues: &mut Issues) -> Vec<(String, bool)> {
    let files = files(root);

    // The whole reason this check exists: the node name is a file stem
    // and nothing else in the schema constrains it, so a typo would be a
    // line that reads as a decision and has no effect on anything.
    for toggle in &list.workflows {
        if files.iter().any(|(_, stem)| *stem == toggle.name) {
            continue;
        }
        let known: Vec<&str> = files.iter().map(|(_, stem)| stem.as_str()).collect();
        issues.push(
            Issue::new(
                format!("`{}` is not a workflow", toggle.name),
                &list.file,
                &list.text,
            )
            .at(toggle.span, format!("no such file under {WORKFLOW_DIR}/"))
            .help(if known.is_empty() {
                format!("{WORKFLOW_DIR}/ holds no workflows")
            } else {
                format!("workflows: {}", known.join(", "))
            }),
        );
    }

    files
        .into_iter()
        .map(|(file, stem)| {
            let enabled = list
                .workflows
                .iter()
                .find(|w| w.name == stem)
                .is_none_or(|w| w.enabled);
            (file, enabled)
        })
        .collect()
}

/// One line per workflow file, pipe separated:
///
///     <file>|<enabled>
///
/// The file name rather than the stem, because that is what the API takes
/// as its `workflow_id`, and `true`/`false` rather than the API's own
/// `active`/`disabled_manually` because this says what should be, not
/// what is.
pub fn render(workflows: &[(String, bool)]) -> String {
    let mut out = String::new();
    for (file, enabled) in workflows {
        let _ = writeln!(out, "{file}|{enabled}");
    }
    out
}

/// Every workflow file, as its name and its stem, sorted by name so two
/// runs on the same tree answer identically.
///
/// Both extensions, because GitHub accepts either and a fork that wrote
/// `.yaml` would otherwise find its declaration matching nothing, which
/// is the failure this file exists to make impossible.
fn files(root: &Path) -> Vec<(String, String)> {
    let dir = root.join(WORKFLOW_DIR);
    let Ok(entries) = std::fs::read_dir(&dir) else {
        return Vec::new();
    };

    let mut out: Vec<(String, String)> = Vec::new();
    for entry in entries.flatten() {
        if !entry.path().is_file() {
            continue;
        }
        let name = entry.file_name().to_string_lossy().into_owned();
        let Some(stem) = name
            .strip_suffix(".yml")
            .or_else(|| name.strip_suffix(".yaml"))
        else {
            continue;
        };
        let stem = stem.to_string();
        out.push((name, stem));
    }
    out.sort();
    out
}
