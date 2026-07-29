# justfile.inc — goojust recipes this module contributes. OPTIONAL.
# run-module.sh appends this verbatim to /usr/share/goojust/justfile.apps,
# which the base justfile imports, so the recipe shows up in `falcos` (the
# OS-name TUI). The comment line above a recipe is its description in the TUI;
# [group('...')] sets its menu group. Recipes needing interactive UI source
# /usr/share/goojust/goojust-helpers.sh for progUpdate/confirm/prompt/choose.
# See manage-dotfiles (setup-dotfiles) and apps/affinity for real ones.

# One-line description shown in the goojust menu
[group('Example')]
template-hello:
	#!/usr/bin/env bash
	set -eou pipefail
	echo "Hello from the template module."
