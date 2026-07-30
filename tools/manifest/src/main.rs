//! The only reader of modules.kdl and the per-module module.kdl files.
//!
//! Everything that needs to know what is in the image asks this: the
//! Containerfile generator, the CI build matrix, the per-target cache
//! tags, the registry cleanup and the Justfile. One parse, on the host.
//! The build consumes resolved values passed as env or generated files,
//! and nothing inside the image parses KDL.
//!
//! Reached through scripts/manifest.sh, which builds it if needed.

mod diag;
mod list;
mod module;
mod options;
mod render;

use list::List;
use std::path::PathBuf;
use std::process::ExitCode;

const USAGE: &str = "\
usage: manifest <command>

Output is one item per line, in declaration order, except where a command
says otherwise.

  flavors           every declared flavor
  default-flavor    the flavor marked default, which builds use when none
                    is given; nothing when no flavors are declared
  pr-flavor         the flavor a pull request builds
  targets           every build target: the ungated `none`, then flavors
  section           the generated Containerfile module section
  summary [target]  what a target is made of, as markdown; every entry
                    when no target is given
  check             validate every manifest, printing what is wrong

Run from the repository root, or set FALCOS_ROOT.
";

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let command = match args.first().map(String::as_str) {
        Some("-h") | Some("--help") => {
            print!("{USAGE}");
            return ExitCode::SUCCESS;
        }
        Some(c) => c,
        None => {
            eprint!("{USAGE}");
            return ExitCode::FAILURE;
        }
    };
    // `summary` is the only command that takes one, since it is the only
    // one whose answer differs per target.
    let target = args.get(1).map(String::as_str);
    if target.is_some() && command != "summary" {
        eprintln!("manifest: `{command}` takes no arguments");
        return ExitCode::FAILURE;
    }
    if args.len() > 2 {
        eprintln!("manifest: `summary` takes at most one target");
        return ExitCode::FAILURE;
    }

    let root = PathBuf::from(std::env::var("FALCOS_ROOT").unwrap_or_else(|_| ".".into()));
    let list_path = root.join("modules.kdl");
    let list_display = list_path.display().to_string();

    let (list, mut issues) = match List::load(&list_display) {
        Ok(v) => v,
        Err(issue) => {
            let mut issues = diag::Issues::default();
            issues.push(*issue);
            issues.report("modules.kdl");
            return ExitCode::FAILURE;
        }
    };

    // Every module's own manifest. Loaded for every command so that a
    // missing or malformed one fails the same way wherever it is noticed,
    // rather than only when something happens to need a field from it.
    let modules: Vec<module::Module> = list
        .entries
        .iter()
        .filter_map(|entry| module::Module::load(entry, &list, &root, &mut issues))
        .collect();
    module::check_graph(&modules, &root, &mut issues);
    let collected = module::resolve_collects(&modules, &root, &mut issues);

    // Rendering is where the module directories and fragments are
    // checked, so `check` runs it too and throws the output away.
    let output = match command {
        "flavors" => lines(list.flavors.iter().map(|f| f.name.clone())),
        "default-flavor" => lines(list.default_flavor().map(str::to_string)),
        "pr-flavor" => lines(list.pr_flavor().map(str::to_string)),
        "targets" => lines(list.targets()),
        "section" | "check" => {
            let section = render::section(&list, &modules, &collected, &root, &mut issues);
            if command == "check" {
                String::new()
            } else {
                section
            }
        }
        "summary" => {
            if let Some(unknown) = target.filter(|t| !list.targets().iter().any(|have| have == t)) {
                issues.push(
                    diag::Issue::new(
                        format!("`{unknown}` is not a build target"),
                        &list_display,
                        &list.text,
                    )
                    .help(format!("targets: {}", list.targets().join(", "))),
                );
            }
            render::summary(&list, &modules, target)
        }
        other => {
            eprintln!("manifest: unknown command `{other}`");
            eprint!("{USAGE}");
            return ExitCode::FAILURE;
        }
    };

    if issues.report(&list_display) {
        return ExitCode::FAILURE;
    }
    print!("{output}");
    if command == "check" {
        eprintln!(
            "manifest: {} modules, {} flavors",
            modules.len(),
            list.flavors.len()
        );
    }
    ExitCode::SUCCESS
}

fn lines(items: impl IntoIterator<Item = String>) -> String {
    items
        .into_iter()
        .map(|s| s + "\n")
        .collect::<Vec<_>>()
        .concat()
}
