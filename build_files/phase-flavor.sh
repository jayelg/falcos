#!/bin/bash
# Copies the flavor file overlay and runs the flavor script
# (desktop.sh/laptop.sh).

set -ouex pipefail

FLAVOR="${FLAVOR:?}"

for v in /ctx/versions-frequent-*.sh; do
    [ -f "$v" ] && source "$v"
done

[ -d "/ctx/files/${FLAVOR}" ] && cp -rT "/ctx/files/${FLAVOR}" "/"
source "/ctx/${FLAVOR}.sh"
