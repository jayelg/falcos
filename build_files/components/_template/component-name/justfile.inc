# justfile.inc — falcos-cli recipes this component contributes. OPTIONAL.
# run-component.sh appends this verbatim to /usr/share/falcos/justfile.apps,
# which the base justfile imports, so the recipe shows up in `falcos` (the
# OS-name TUI). The comment line above a recipe is its description in the TUI;
# [group('...')] sets its menu group. Recipes needing interactive UI source
# /usr/share/falcos/falcos-helpers.sh for prog/confirm/prompt/choose.
# See core/manage-dotfiles (setup-dotfiles) and apps/affinity for real ones.

# One-line description shown in the falcos-cli menu
[group('Example')]
template-hello:
	#!/usr/bin/env bash
	set -eou pipefail
	echo "Hello from the template component."
