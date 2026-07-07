#!/bin/bash
# Sources one themed group of common/core/ scripts, named as arguments by
# that group's RUN instruction in the Containerfile.

set -ouex pipefail

for v in /ctx/versions-core-*.sh; do
    [ -f "$v" ] && source "$v"
done

for f in "$@"; do
    source "/ctx/common/core/$f"
done
