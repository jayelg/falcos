//! files/ overlay collisions.
//!
//! Every overlay is copied over the image root in build order, so two
//! modules shipping the same path means the later one silently wins and
//! the earlier one's file is never in the image. Nothing about that is
//! visible in either module, and it survives until someone notices the
//! setting they shipped has no effect.
//!
//! Deliberate replacement stays possible, as `overrides "<path>"`, and
//! is checked both ways: without it a collision fails, and with nothing
//! to override it fails too, so the escape hatch cannot outlive the
//! collision it was added for.

use crate::diag::{Issue, Issues};
use crate::module::Module;
use std::collections::{BTreeMap, BTreeSet};
use std::path::Path;

/// Every path an overlay puts in the image, to the modules shipping it, as
/// indices into `modules` in build order.
///
/// Covers every module whatever flavor it is gated to. Gating is applied
/// by the caller: at comparison time in `check`, by target in `owns`.
pub type Index = BTreeMap<String, Vec<usize>>;

/// Built once and handed to both readers.
///
/// Split out of `check` rather than rebuilt beside it. The collision check
/// and `owns` are two questions about one fact, and a second walk of every
/// overlay would only rediscover what the first already knew.
pub fn index(modules: &[Module], root: &Path) -> Index {
    let mut shipped: Index = BTreeMap::new();
    for (index, module) in modules.iter().enumerate() {
        let overlay = root.join("modules").join(&module.dir).join("files");
        for path in overlay_paths(&overlay) {
            shipped.entry(path).or_default().push(index);
        }
    }
    shipped
}

/// The module whose overlay actually puts a file at `path` in a target's
/// image. One line, the module path, or nothing when none does.
///
/// Filtered by target from the start, because the index deliberately holds
/// every module whatever it is gated to. `check` gets away with that by
/// asking `coinstalled` at comparison time; an answer handed to a caller
/// has no such second chance. Exposing it unfiltered would reproduce the
/// bug `find-provider` already had and had fixed, where a path shipped
/// only by a module gated to `desktop` read as shipped on `laptop` and on
/// the ungated build too. No target means every module, which is the whole
/// list rather than any image that gets built.
///
/// The last shipper in build order, not the first: overlays are copied in
/// build order, so the later one is the file that survives into the image.
/// Without a declared `overrides` two shippers are already a lint failure,
/// so in a tree that passes `check` this names the only module whose file
/// could be there.
///
/// Answers over what is shipped, where `find-provider` answers over what
/// is declared, and the two are complementary. A `provides-file` names a
/// contract whoever writes it, including a module that writes it from
/// module.sh; this names the overlay a file physically came from. A
/// package-installed path is in neither and could not be without `rpm -qf`
/// on a built image.
pub fn owns(modules: &[Module], shipped: &Index, path: &str, target: Option<&str>) -> String {
    let Some(owners) = shipped.get(path) else {
        return String::new();
    };
    owners
        .iter()
        .rev()
        .find(|&&owner| in_target(&modules[owner], target))
        .map(|&owner| format!("{}\n", modules[owner].path))
        .unwrap_or_default()
}

/// Whether a module lands in a target's image. No target means every
/// module, which is how the rest of the per-target commands read.
fn in_target(module: &Module, target: Option<&str>) -> bool {
    match (&module.flavor, target) {
        (None, _) => true,
        (Some(_), None) => true,
        (Some(gate), Some(target)) => gate == target,
    }
}

pub fn check(modules: &[Module], shipped: &Index, issues: &mut Issues) {
    let mut used: Vec<BTreeSet<&str>> = vec![BTreeSet::new(); modules.len()];

    for (path, owners) in shipped {
        for (position, &later) in owners.iter().enumerate() {
            // The nearest earlier module that ends up in the same image
            // as this one: whichever it is, this overlay lands on top of
            // it.
            let Some(&earlier) = owners[..position]
                .iter()
                .rev()
                .find(|&&earlier| coinstalled(&modules[earlier], &modules[later]))
            else {
                continue;
            };
            if let Some(decl) = modules[later].overrides.iter().find(|d| &d.name == path) {
                used[later].insert(decl.name.as_str());
                continue;
            }
            issues.push(
                Issue::new(
                    format!(
                        "`{}` overwrites `{path}`, which `{}` also ships",
                        modules[later].path, modules[earlier].path
                    ),
                    &modules[later].file,
                    &modules[later].text,
                )
                .help(format!(
                    "overlays are copied in build order, so this one wins and the other file never reaches the image. \
                     Rename one of the two, or declare `overrides \"{path}\"` here if replacing it is the point"
                )),
            );
        }
    }

    for (index, module) in modules.iter().enumerate() {
        for decl in &module.overrides {
            if used[index].contains(decl.name.as_str()) {
                continue;
            }
            issues.push(
                Issue::new(
                    format!(
                        "`{}` overrides `{}`, which no earlier module ships",
                        module.path, decl.name
                    ),
                    &module.file,
                    &module.text,
                )
                .at(decl.span, "nothing to replace")
                .help("an override is checked, so it cannot outlive the collision it was added for; drop it, or check the path against what the other module actually ships"),
            );
        }
    }
}

/// Two modules land in the same image unless they are gated to different
/// flavors. The same module listed under two flavors is not a collision
/// with itself.
fn coinstalled(a: &Module, b: &Module) -> bool {
    if a.path == b.path {
        return false;
    }
    match (&a.flavor, &b.flavor) {
        (Some(a), Some(b)) => a == b,
        _ => true,
    }
}

/// Every file in an overlay, as the absolute path it becomes in the
/// image. Directories are not paths a module owns — two modules both
/// shipping into /usr/bin is the normal case, and only the files in
/// there can collide.
fn overlay_paths(overlay: &Path) -> Vec<String> {
    let mut out = Vec::new();
    let mut dirs = vec![overlay.to_path_buf()];
    while let Some(dir) = dirs.pop() {
        let Ok(entries) = std::fs::read_dir(&dir) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            // symlink_metadata, so a symlink is the thing shipped rather
            // than whatever it points at.
            let Ok(meta) = path.symlink_metadata() else {
                continue;
            };
            if meta.is_dir() {
                dirs.push(path);
            } else if let Ok(rel) = path.strip_prefix(overlay) {
                out.push(format!("/{}", rel.display()));
            }
        }
    }
    out
}
