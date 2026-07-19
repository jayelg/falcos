### Looking Glass kvmfr module (shared-memory transport between host and VM)
# Desktop flavor only (COMPONENT_FLAVORS in Containerfile.part): pairs with
# the VFIO GPU-passthrough setup shipped by files/desktop.
source /ctx/lib/dkms-helpers.sh
kernel_devel_install "${DKMS_BUILD_DEPS[@]}"

git clone --quiet --depth 1 --branch "$LOOKING_GLASS_TAG" \
    https://github.com/gnif/LookingGlass.git /tmp/looking-glass

# Version comes from upstream's dkms.conf at LOOKING_GLASS_TAG, no manual
# pin to keep in sync
KVMFR_VERSION="$(dkms_conf_version /tmp/looking-glass/module)"

dkms_build_module kvmfr "$KVMFR_VERSION" /tmp/looking-glass/module

kernel_devel_remove "${DKMS_BUILD_DEPS_REMOVE[@]}"
rm -rf /tmp/looking-glass
