#!/bin/bash
# Runs one themed group of common/frequent/ scripts, named explicitly as
# arguments by the Containerfile's RUN instruction for that group — same
# per-group cache isolation as phase-core.sh. The flavor script
# (desktop.sh/laptop.sh) is handled separately by phase-flavor.sh, since
# that group is inherently flavor-divergent and shouldn't be bundled with
# groups that are common to both flavors.

set -ouex pipefail

for v in /ctx/versions-frequent-*.sh; do
    [ -f "$v" ] && source "$v"
done

for f in "$@"; do
    source "/ctx/common/frequent/$f"
done
