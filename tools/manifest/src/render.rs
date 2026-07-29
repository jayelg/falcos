//! The generated Containerfile section.
//!
//! One RUN layer per list entry, plus the two ARGs the phases below the
//! section read. Everything here is resolved on the host: nothing inside
//! the image parses a manifest.

use crate::diag::{Issue, Issues};
use crate::list::{Entry, List};
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
    sinks: &BTreeMap<String, Vec<(String, String)>>,
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

        let inc = dir.join("Containerfile.inc");
        let block = if inc.is_file() {
            verbatim(entry, &inc, flavor_arg_emitted, list, issues)
        } else {
            standard(entry, module, sinks.get(&entry.path))
        };
        let _ = write!(out, "{block}\n\n");

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

fn standard(
    entry: &Entry,
    module: Option<&Module>,
    sinks: Option<&Vec<(String, String)>>,
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
    // Only the sinks this module actually contributes to, resolved from
    // the files it ships, so the runner appends without knowing any path
    // and a module that contributes nothing carries no env at all.
    if let Some(sinks) = sinks.filter(|s| !s.is_empty()) {
        let pairs: Vec<String> = sinks
            .iter()
            .map(|(file, path)| format!("{file}={path}"))
            .collect();
        let _ = write!(env, "MODULE_SINKS=\"{}\" ", pairs.join(" "));
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
    if let Some(flavor) = &entry.flavor {
        let _ = writeln!(out, "# ---- [{flavor}] ----");
    }
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
/// which replaces the standard block rather than adding to it.
fn verbatim(
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

    // The fragment replaces the standard block, so it has to spell the
    // gate out itself. Left to agree by hand it would silently ship a
    // gated module on every flavor.
    if let Some(flavor) = &entry.flavor {
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
                    "a fragment replaces the generated block, so it has to carry the gate itself",
                ),
            ),
        }
    }

    let mut out = String::new();
    if let Some(flavor) = &entry.flavor {
        let _ = writeln!(out, "# ---- [{flavor}] ----");
    }
    let _ = write!(
        out,
        "# ---- {path} (verbatim from modules/{path}/Containerfile.inc) ----\n{}",
        body.trim_end_matches('\n')
    );
    out
}
