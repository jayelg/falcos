//! The generated Containerfile section.
//!
//! One RUN layer per list entry, plus the two ARGs the phases below the
//! section read. Everything here is resolved on the host: nothing inside
//! the image parses a manifest.

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

        // Once per entry rather than once per block, since the flavor is
        // a property of the entry and both blocks carry it.
        if let Some(flavor) = &entry.flavor {
            let _ = writeln!(out, "# ---- [{flavor}] ----");
        }
        let _ = write!(out, "{}\n\n", blocks.join("\n\n"));

        if dir.join("finalize.sh").is_file() {
            finalize.push(match &entry.flavor {
                Some(f) => format!("{}:{f}", entry.path),
                None => entry.path.clone(),
            });
        }
    }

    // Nothing gated, so nothing above needed it, but the flavor and
    // finalize phases below the section still do.
    if !flavor_arg_emitted {
        let _ = write!(out, "{FLAVOR_ARG}\n\n");
    }

    // Resolved here because this is the only thing that reads the list.
    // The finalize phase used to recover this by reparsing the list
    // inside the image, which was a second implementation of the format.
    let _ = write!(
        out,
        "# ---- finalize hook order ----\n\
         # Modules shipping a finalize.sh, in list order, resolved on the host.\n\
         ARG FINALIZE_ORDER=\"{}\"\n\n",
        finalize.join(" ")
    );

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
    let included: Vec<&Entry> = list
        .entries
        .iter()
        .filter(|e| match (&e.flavor, target) {
            (None, _) => true,
            (Some(_), None) => true,
            (Some(gate), Some(target)) => gate == target,
        })
        .collect();
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

    let path = &entry.path;
    let mut out = String::new();
    let _ = write!(
        out,
        "# ---- {path} ----\n\
         RUN --mount=type=bind,from=ctx,source=/modules/{path},target=/ctx/modules/{path} \\\n    \
         --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \\\n    \
         --mount=type=cache,target=/var/cache \\\n    \
         --mount=type=cache,target=/var/log \\\n    \
         --mount=type=tmpfs,target=/tmp \\\n    \
         {secrets}{env}bash /ctx/lib/run-module.sh /ctx/modules/{path}"
    );
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
        "# ---- {path} (verbatim from modules/{path}/Containerfile.inc) ----\n{}",
        body.trim_end_matches('\n')
    );
    out
}
