#!/bin/bash
# Runs one themed group of common/core/ scripts, named explicitly as
# arguments by the Containerfile's RUN instruction for that group. Each
# group is its own RUN/layer, scoped to only the files (and version-pin
# file, if any) it actually needs — so a change to one group's script or
# pin doesn't invalidate a sibling group's cache.

set -ouex pipefail

for v in /ctx/versions-core-*.sh; do
    [ -f "$v" ] && source "$v"
done

for f in "$@"; do
    source "/ctx/common/core/$f"
done
