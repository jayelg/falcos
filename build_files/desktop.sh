### Looking Glass kvmfr module (shared-memory transport between host and VM)
source /ctx/lib/dkms-helpers.sh
kernel_devel_install dkms gcc make git sbsigntools openssl

git clone --quiet --depth 1 --branch "$LOOKING_GLASS_TAG" \
    https://github.com/gnif/LookingGlass.git /tmp/looking-glass

# Version comes from upstream's dkms.conf at LOOKING_GLASS_TAG, no manual
# pin to keep in sync
KVMFR_VERSION="$(dkms_conf_version /tmp/looking-glass/module)"

dkms_build_module kvmfr "$KVMFR_VERSION" /tmp/looking-glass/module

# Allow the kvm group to access the kvmfr device (user must be in the kvm group)
install -Dm644 /dev/null /usr/lib/udev/rules.d/99-kvmfr.rules
printf 'SUBSYSTEM=="kvmfr", OWNER="root", GROUP="kvm", MODE="0660"\n' \
    > /usr/lib/udev/rules.d/99-kvmfr.rules

kernel_devel_remove dkms gcc make sbsigntools
rm -rf /tmp/looking-glass

### VFIO
# The vfio-rebind-gpu-usb unit is enabled in enable-services.sh and
# dracut.conf.d/99-vfio.conf is picked up by phase-finalize.sh's initramfs regen.
