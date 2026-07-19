#!/bin/bash
# Copies the flavor file overlay and applies os-release branding.
# Callers pass FLAVOR and IMAGE_VERSION in the environment.

set -ouex pipefail

FLAVOR="${FLAVOR:?}"

[ -d "/ctx/files/${FLAVOR}" ] && cp -rT "/ctx/files/${FLAVOR}" "/"

source /ctx/lib/brand-helpers.sh
brand_os_release
