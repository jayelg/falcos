#!/bin/bash
# Applies os-release branding. Flavor-specific files ship in flavor-gated
# modules (e.g. vfio-passthrough, laptop-tweaks), so there is no
# per-flavor overlay to copy here, and the branding itself is the brand
# rather than the flavor: a flavor is an image variant, not a machine
# identity. The phase keeps its number because this is where the flavor
# cache fork happens, not because it reads FLAVOR.
#
# IMAGE_VERSION arrives in the environment, as it does on every phase
# below the module layers.

set -ouex pipefail

source /ctx/lib/brand-helpers.sh
brand_os_release
