#!/bin/bash
# Applies os-release branding for the flavor. Flavor-specific files now
# ship in flavor-gated components (e.g. vfio-passthrough, laptop-tweaks),
# so there is no per-flavor overlay to copy here.
# Callers pass FLAVOR and IMAGE_VERSION in the environment.

set -ouex pipefail

FLAVOR="${FLAVOR:?}"

source /ctx/lib/brand-helpers.sh
brand_os_release
