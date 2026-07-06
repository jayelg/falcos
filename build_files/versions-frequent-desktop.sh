# Pinned versions consumed by build_files/desktop.sh (Looking Glass/kvmfr)
# — split out so bumping these doesn't invalidate unrelated frequent RUN
# groups. Only relevant to the desktop flavor, but the laptop build mounts
# this file too since the flavor-script RUN group is already
# flavor-divergent by nature.
#
# Tracked by Renovate (.github/renovate.json5 customManagers). Bumped via
# PR — edit the value in a Renovate PR, don't move the annotation comment
# off its version line.

# Looking Glass (kvmfr module) release tag.
# renovate: datasource=github-releases depName=gnif/LookingGlass
LOOKING_GLASS_TAG="B7"
# kvmfr's own PACKAGE_VERSION from upstream's module/dkms.conf at
# LOOKING_GLASS_TAG — keep these two in sync manually, Renovate can't see
# inside the tagged tree to track this one on its own.
KVMFR_VERSION="0.0.12"
