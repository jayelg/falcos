#!/bin/bash
# Copies the flavor file overlay and runs the flavor script
# (flavors/desktop.sh or flavors/laptop.sh).

set -ouex pipefail

FLAVOR="${FLAVOR:?}"

[ -d "/ctx/files/${FLAVOR}" ] && cp -rT "/ctx/files/${FLAVOR}" "/"
source "/ctx/flavors/${FLAVOR}.sh"
