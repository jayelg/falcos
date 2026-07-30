//! The generated Containerfile section.
//!
//! One RUN layer per build phase and one per list entry, plus the ARGs
//! the layers below the modules read. Everything here is resolved on the
//! host: nothing inside the image parses a manifest.

use crate::diag::{Issue, Issues};
use crate::list::{Entry, List, NO_FLAVOR};
use crate::module::Module;
use std::collections::BTreeMap;
use std::fmt::Write as _;
use std::path::Path;

/// Declared immediately above the first layer that can read it, never at
/// the top. An ARG in scope is part of the cache key of every RUN below
/// it, whether or not that RUN mentions it, so declaring it early would
/// fork the cache at the first module and leave the flavors sharing no
/// layers at all.
const FLAVOR_ARG: &str = "\
# ---- flavor gate ----
# Declared here rather than above: an ARG in scope is part of the cache
# key of every RUN below it, so every layer above this one is shared by
# every flavor and by the ungated build.
#
# No default, so an unset FLAVOR is the ungated set rather than a flavor
# nobody asked for. scripts/build.sh always passes one.
ARG FLAVOR";

/// CI passes the build date, so this changes every day. Declared here
/// for the same reason as the flavor gate: in scope above the modules it
/// would rebuild all forty of them once a day on its own, which it did
/// until it was moved.
const IMAGE_VERSION_ARG: &str = "\
# ---- image version ----
# The YYYYMMDD build date in CI. Below the modules because an ARG in
# scope is part of the cache key of every RUN under it, whether or not
# that RUN mentions it.
ARG IMAGE_VERSION=dev";

/// Where the module layers sit among the build phases. A phase numbered
/// below this runs before them, one at or above runs after, which is
/// what the prefixes on build-phases/*.sh have always looked like they
/// meant.
const MODULE_SLOT: u32 = 50;

pub fn section(
    list: &List,
    modules: &[Module],
    collected: &BTreeMap<String, Vec<(String, String)>>,
    root: &Path,
    issues: &mut Issues,
) -> String {
    let mut out = String::new();
    let mut flavor_arg_emitted = false;
    let mut finalize: Vec<String> = Vec::new();

    let phases = phases(root, issues);
    for (_, file) in phases.iter().filter(|(number, _)| *number < MODULE_SLOT) {
        let _ = write!(out, "{}\n\n", phase(file, false));
    }

    for entry in &list.entries {
        let dir = root.join("modules").join(&entry.path);
        if !dir.is_dir() {
            issues.push(
                Issue::new(
                    format!("`{}` does not resolve to a module directory", entry.path),
                    &list.file,
                    &list.text,
                )
                .at(entry.span, "no such module")
                .help(format!("expected {}", dir.display())),
            );
            continue;
        }

        // The ARG goes directly above the first gated layer, which is the
        // first one that can read it.
        if entry.flavor.is_some() && !flavor_arg_emitted {
            let _ = write!(out, "{FLAVOR_ARG}\n\n");
            flavor_arg_emitted = true;
        }

        // An entry whose manifest failed to load has already been
        // reported; it renders with no options rather than a second time.
        let module = modules
            .iter()
            .find(|m| m.path == entry.path && m.flavor == entry.flavor);

        // A fragment adds to the generated block rather than replacing
        // it, so an entry can emit both, in the declared order.
        let inc = dir.join("Containerfile.inc");
        let mut blocks: Vec<String> = Vec::new();
        let fragment_after = module.is_some_and(|m| m.fragment_after);
        if inc.is_file() && !fragment_after {
            blocks.push(fragment(entry, &inc, flavor_arg_emitted, list, issues));
        }
        if module.is_none_or(|m| m.standard_layer) {
            blocks.push(standard(entry, module, collected.get(&entry.path)));
        }
        if inc.is_file() && fragment_after {
            blocks.push(fragment(entry, &inc, flavor_arg_emitted, list, issues));
        }

        // One banner per entry, never one per block: two of them under
        // the same name reads as the module being emitted twice, which
        // is the first thing a reviewer would go looking for. The
        // fragment labels itself underneath instead.
        if let Some(flavor) = &entry.flavor {
            let _ = writeln!(out, "# ---- [{flavor}] ----");
        }
        let _ = writeln!(out, "# ---- {} ----", entry.path);
        let _ = write!(out, "{}\n\n", blocks.join("\n\n"));

        if dir.join("finalize.sh").is_file() {
            finalize.push(match &entry.flavor {
                Some(f) => format!("{}:{f}", entry.path),
                None => entry.path.clone(),
            });
        }
    }

    // Nothing gated, so no module layer needed it, but the phases below
    // them are still passed a flavor.
    if !flavor_arg_emitted {
        let _ = write!(out, "{FLAVOR_ARG}\n\n");
    }

    // Resolved here because this is the only thing that reads the list.
    // The finalize phase used to recover this by reparsing the list
    // inside the image, which was a second implementation of the format.
    let _ = write!(
        out,
        "# ---- finalize hook order ----\n\
         # Modules shipping a finalize.sh, in build order, resolved on the host.\n\
         ARG FINALIZE_ORDER=\"{}\"\n\n",
        finalize.join(" ")
    );

    let _ = write!(out, "{IMAGE_VERSION_ARG}\n\n");

    for (_, file) in phases.iter().filter(|(number, _)| *number >= MODULE_SLOT) {
        let _ = write!(out, "{}\n\n", phase(file, true));
    }

    out
}

/// Every build-phases/*.sh, as its number and filename, in build order.
/// A drop-in directory: the prefix is the whole declaration, so adding a
/// phase is adding a file.
fn phases(root: &Path, issues: &mut Issues) -> Vec<(u32, String)> {
    let dir = root.join("build-phases");
    let Ok(entries) = std::fs::read_dir(&dir) else {
        return Vec::new();
    };

    let mut out: Vec<(u32, String)> = Vec::new();
    for entry in entries.flatten() {
        let name = entry.file_name().to_string_lossy().into_owned();
        if !name.ends_with(".sh") || !entry.path().is_file() {
            continue;
        }
        // The number is what orders the phase against the modules, so a
        // file without one has no place to go rather than a default.
        let number = name
            .split_once('-')
            .and_then(|(prefix, _)| prefix.parse::<u32>().ok());
        match number {
            Some(number) => out.push((number, name)),
            None => {
                let file = dir.join(&name).display().to_string();
                issues.push(
                    Issue::new(format!("`{name}` has no phase number"), &file, "")
                        .help(format!(
                            "name it <number>-{name}: below {MODULE_SLOT} to run before the module layers, {MODULE_SLOT} or above to run after"
                        )),
                );
            }
        }
    }
    out.sort();
    out
}

/// One phase layer.
///
/// What a phase gets is decided by which side of the module layers it is
/// on, not by the script, because the difference is a property of the
/// build rather than of what the file happens to read.
///
/// A phase below the modules sees the resolved build: the flavor, the
/// image version and the finalize hook order, plus lib and the module
/// directories. One above them sees none of that and mounts only its own
/// script: FLAVOR and IMAGE_VERSION are not declared yet, and binding
/// the module tree into the first layer of the build would put every
/// module's content in its cache key.
fn phase(file: &str, below_modules: bool) -> String {
    let mut out = format!(
        "# ---- phase {file} ----\n\
         RUN --mount=type=bind,from=ctx,source=/{file},target=/ctx/{file} \\\n    "
    );
    if below_modules {
        out.push_str("--mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \\\n    ");
        out.push_str("--mount=type=bind,from=ctx,source=/modules,target=/ctx/modules \\\n    ");
    }
    out.push_str(
        "--mount=type=cache,target=/var/cache \\\n    \
         --mount=type=cache,target=/var/log \\\n    \
         --mount=type=tmpfs,target=/tmp \\\n    ",
    );
    if below_modules {
        out.push_str(
            "FLAVOR=${FLAVOR} IMAGE_VERSION=${IMAGE_VERSION} FINALIZE_ORDER=\"${FINALIZE_ORDER}\" ",
        );
    }
    let _ = write!(out, "/ctx/{file}");
    out
}

/// What a target is made of, as markdown, in the order the layers build.
/// Written to the CI job summary, so a published image has a record of the
/// modules it carries and the options each was given without anyone having
/// to read forty RUN lines. A module's `description` exists for this.
///
/// No target means every entry, which is the whole list rather than any
/// image that gets built.
pub fn summary(list: &List, modules: &[Module], target: Option<&str>) -> String {
    let included: Vec<&Entry> = list.entries.iter().filter(|e| in_target(e, target)).collect();
    let gated = included.iter().filter(|e| e.flavor.is_some()).count();

    let mut out = String::new();
    let count = included.len();
    let _ = match target {
        Some(NO_FLAVOR) => writeln!(out, "{count} modules, the ungated set."),
        Some(target) => writeln!(out, "{count} modules, {gated} of them gated to `{target}`."),
        None => writeln!(out, "{count} modules, {gated} of them gated to a flavor."),
    };
    let _ = write!(
        out,
        "\n| Module | Description | Options |\n| --- | --- | --- |\n"
    );

    for entry in included {
        let module = modules
            .iter()
            .find(|m| m.path == entry.path && m.flavor == entry.flavor);
        let mut name = format!("`{}`", entry.path);
        if let Some(flavor) = &entry.flavor {
            let _ = write!(name, " `[{flavor}]`");
        }
        if let Some(variant) = &entry.variant {
            let _ = write!(name, " `variant={variant}`");
        }
        let options: Vec<String> = module
            .map(|m| m.resolved.as_slice())
            .unwrap_or_default()
            .iter()
            .map(|(name, value)| format!("`{name}=\"{}\"`", cell(value)))
            .collect();
        let _ = writeln!(
            out,
            "| {name} | {} | {} |",
            cell(module.map(|m| m.description.as_str()).unwrap_or_default()),
            options.join(" ")
        );
    }
    out
}

/// A pipe would end the column, and neither a description nor an option
/// value is stopped from holding one.
fn cell(text: &str) -> String {
    text.replace('|', "\\|")
}

/// Whether an entry lands in a target's image. No target means every
/// entry, which is the whole list rather than any image that gets built.
fn in_target(entry: &Entry, target: Option<&str>) -> bool {
    match (&entry.flavor, target) {
        (None, _) => true,
        (Some(_), None) => true,
        (Some(gate), Some(target)) => gate == target,
    }
}

/// Every pinned asset, pipe separated, one per line:
///
///     <module>|<name>|<manifest>|<version>|<sha256>|<from>|<url>
///
/// Two consumers, neither of which should be carrying a table of its own:
/// the checksum workflow, which recomputes a stale hash and needs the
/// manifest to rewrite, and the SBOM supplement, which needs the payloads
/// an RPM inventory cannot see. Absent fields are empty, so the column
/// count is fixed.
///
/// Delimited with | rather than a tab because bash `read` collapses
/// consecutive IFS whitespace characters (including tab), which shifts
/// columns when a field is empty.
pub fn assets(list: &List, modules: &[Module], target: Option<&str>) -> String {
    let mut out = String::new();
    // A module listed under two flavors is two entries carrying the same
    // pins, and a pin is recomputed and reported once however many images
    // it lands in.
    let mut seen: Vec<(&str, &str)> = Vec::new();
    for entry in list.entries.iter().filter(|e| in_target(e, target)) {
        let Some(module) = modules
            .iter()
            .find(|m| m.path == entry.path && m.flavor == entry.flavor)
        else {
            continue;
        };
        for asset in &module.assets {
            if seen.contains(&(module.path.as_str(), asset.name.as_str())) {
                continue;
            }
            seen.push((module.path.as_str(), asset.name.as_str()));
            let _ = writeln!(
                out,
                "{}|{}|modules/{}/module.kdl|{}|{}|{}|{}",
                module.path,
                asset.name,
                module.path,
                asset.version.as_deref().unwrap_or_default(),
                asset.sha256.as_deref().unwrap_or_default(),
                asset.from.as_str(),
                asset.url_resolved().unwrap_or_default(),
            );
        }
    }
    out
}

/// The module that provides a contract file path. One line, the module
/// path, or nothing if no enabled module provides it.
pub fn find_provider(list: &List, modules: &[Module], file_path: &str) -> String {
    for module in modules {
        for decl in &module.provides_files {
            if decl.name == file_path {
                return format!("{}\n", module.path);
            }
        }
    }
    String::new()
}

/// Unique secret IDs the enabled modules declare, one per line. When a
/// target is given, only modules that land in that target's image are
/// included.
pub fn secrets(list: &List, modules: &[Module], target: Option<&str>) -> String {
    let mut seen: Vec<&str> = Vec::new();
    let mut out = String::new();
    for entry in list.entries.iter().filter(|e| in_target(e, target)) {
        let Some(module) = modules
            .iter()
            .find(|m| m.path == entry.path && m.flavor == entry.flavor)
        else {
            continue;
        };
        for decl in &module.secrets {
            if seen.contains(&decl.name.as_str()) {
                continue;
            }
            seen.push(&decl.name);
            let _ = writeln!(out, "{}", decl.name);
        }
    }
    out
}

/// Contract file paths the enabled modules declare and the finished image
/// still carries, one per line. A `build-only` path is left out: the
/// module that writes it removes it again in its finalize hook, so
/// asserting it exists would fail on a correct image. When a target is
/// given, only modules that land in that target's image are included.
pub fn contract_files(list: &List, modules: &[Module], target: Option<&str>) -> String {
    let mut seen: Vec<&str> = Vec::new();
    let mut out = String::new();
    for entry in list.entries.iter().filter(|e| in_target(e, target)) {
        let Some(module) = modules
            .iter()
            .find(|m| m.path == entry.path && m.flavor == entry.flavor)
        else {
            continue;
        };
        for decl in &module.provides_files {
            if module.provides_files_build_only.contains(&decl.name) {
                continue;
            }
            if seen.contains(&decl.name.as_str()) {
                continue;
            }
            seen.push(&decl.name);
            let _ = writeln!(out, "{}", decl.name);
        }
    }
    out
}

fn standard(
    entry: &Entry,
    module: Option<&Module>,
    collected: Option<&Vec<(String, String)>>,
) -> String {
    let mut env = String::new();
    if let Some(flavor) = &entry.flavor {
        let _ = write!(env, "FLAVOR_GATE={flavor} ");
    }
    // Every declared option, always, defaults included: a module's script
    // reads OPT_* unconditionally rather than guarding each one. A variant
    // has already been folded in, which is why nothing about it reaches
    // the build.
    for (name, value) in module.map(|m| m.resolved.as_slice()).unwrap_or_default() {
        let _ = write!(env, "{name}=\"{value}\" ");
    }
    // Only the files this module actually contributes, resolved from what
    // it ships, so the runner needs no path of its own and a module that
    // contributes nothing carries no env at all.
    if let Some(collected) = collected.filter(|c| !c.is_empty()) {
        let pairs: Vec<String> = collected
            .iter()
            .map(|(file, into)| format!("{file}={into}"))
            .collect();
        let _ = write!(env, "MODULE_COLLECT=\"{}\" ", pairs.join(" "));
    }

    // One line per asset field, unlike everything else here, because a
    // module with seven pins carries twenty env pairs and the generated
    // file is committed to be read. Only a module with assets gets them,
    // so no line that has none moves.
    let mut assets = String::new();
    for asset in module.map(|m| m.assets.as_slice()).unwrap_or_default() {
        for (name, value) in asset.env() {
            let _ = write!(assets, "{name}=\"{value}\" \\\n    ");
        }
    }

    // required=false always: a build without the secret is a supported
    // build that skips what the secret enables, and the alternative is a
    // repository only its owner can build.
    let mut secrets = String::new();
    for decl in module.map(|m| m.secrets.as_slice()).unwrap_or_default() {
        let id = &decl.name;
        let _ = write!(
            secrets,
            "--mount=type=secret,id={id},target=/run/secrets/{id},required=false \\\n    "
        );
    }
    // Passed explicitly rather than relied on being in scope, so the
    // dependency is visible in the generated file. Prepended, so the args
    // read before the gate and the options, as they did when these blocks
    // were written by hand.
    for decl in module
        .map(|m| m.args.as_slice())
        .unwrap_or_default()
        .iter()
        .rev()
    {
        let name = &decl.name;
        env.insert_str(0, &format!("{name}=${{{name}}} "));
    }

    // Declared packages, one dnf5 install per unique (family, enablerepo)
    // group, chained with && before the module runner.
    let packages_cmd = packages_install(module);

    let path = &entry.path;
    let mut out = String::new();
    let _ = write!(
        out,
        "RUN --mount=type=bind,from=ctx,source=/modules/{path},target=/ctx/modules/{path} \\\n    \
         --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \\\n    \
         --mount=type=cache,target=/var/cache \\\n    \
         --mount=type=cache,target=/var/log \\\n    \
         --mount=type=tmpfs,target=/tmp \\\n    \
         {secrets}{assets}{env}{packages_cmd}bash /ctx/lib/run-module.sh /ctx/modules/{path}"
    );
    out
}

/// The dnf5 install commands for declared packages, if any. One command
/// per unique (family, enablerepo) group, each ending with ` && ` so the
/// runner still executes when there are none. On Fedora the verb is
/// always dnf5; a second family would pick its own.
fn packages_install(module: Option<&Module>) -> String {
    let groups = match module {
        Some(m) if !m.packages.is_empty() => m.packages.as_slice(),
        _ => return String::new(),
    };
    let mut out = String::new();
    for group in groups {
        let pkgs = group.packages.join(" ");
        match &group.enablerepo {
            Some(repo) => {
                let _ = write!(out, "dnf5 install -y --enablerepo='{repo}' {pkgs} && ");
            }
            None => {
                let _ = write!(out, "dnf5 install -y {pkgs} && ");
            }
        }
    }
    out
}

/// A module whose needs the field sets cannot express ships a fragment,
/// inlined verbatim above the standard block, or below it when the
/// manifest says `position "after"`.
fn fragment(
    entry: &Entry,
    inc: &Path,
    flavor_arg_emitted: bool,
    list: &List,
    issues: &mut Issues,
) -> String {
    let body = std::fs::read_to_string(inc).unwrap_or_default();
    let path = &entry.path;

    // A fragment above the ARG that expands FLAVOR would get an empty
    // string, silently, so it is an error rather than a surprise in the
    // built image.
    if !flavor_arg_emitted && (body.contains("${FLAVOR}") || body.contains("$FLAVOR")) {
        issues.push(
            Issue::new(
                format!("`{path}` expands FLAVOR above the flavor gate"),
                &list.file,
                &list.text,
            )
            .at(entry.span, "listed above the first flavor-gated module")
            .help("ARG FLAVOR is declared directly above the first gated entry, so a fragment before it would expand to an empty string"),
        );
    }

    // Nothing in a fragment is conditional: the generated Containerfile
    // is one file for every target, and the only per-flavor mechanism is
    // the gate the runner checks. The standard block carries it, so a
    // fragment only has to when it runs something of its own.
    let runs = body.lines().any(|l| l.trim_start().starts_with("RUN "));
    if let Some(flavor) = entry.flavor.as_ref().filter(|_| runs) {
        let declared = body
            .split("FLAVOR_GATE=")
            .nth(1)
            .map(|rest| rest.split_whitespace().next().unwrap_or_default());
        match declared {
            Some(d) if d == flavor => {}
            Some(d) => issues.push(
                Issue::new(
                    format!("`{path}` is listed under `{flavor}` but its fragment gates on `{d}`"),
                    &list.file,
                    &list.text,
                )
                .at(entry.span, "listed here"),
            ),
            None => issues.push(
                Issue::new(
                    format!(
                        "`{path}` is listed under `{flavor}` but its fragment sets no FLAVOR_GATE"
                    ),
                    &list.file,
                    &list.text,
                )
                .at(entry.span, "the flavor gate would be silently ignored")
                .help(
                    "a fragment is emitted unconditionally, so anything it runs has to carry the gate itself",
                ),
            ),
        }
    }

    let mut out = String::new();
    let _ = write!(
        out,
        "# verbatim from modules/{path}/Containerfile.inc:\n{}",
        body.trim_end_matches('\n')
    );
    out
}
