#!/bin/bash
# Final frequent-phase group: flavor-specific files + the flavor script
# (desktop.sh/laptop.sh). Kept separate from phase-frequent.sh's grouped
# common scripts since this group is inherently flavor-divergent — bundling
# it in would force a per-flavor cache miss on groups that don't actually
# need to differ between desktop and laptop.

set -ouex pipefail

FLAVOR="${FLAVOR:?}"

for v in /ctx/versions-frequent-*.sh; do
    [ -f "$v" ] && source "$v"
done

[ -d "/ctx/files/${FLAVOR}" ] && cp -rT "/ctx/files/${FLAVOR}" "/"
source "/ctx/${FLAVOR}.sh"
