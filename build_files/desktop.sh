### Looking Glass
# kvmfr (shared-memory transport between host and VM), built via DKMS —
# same rationale as common/core/080-xone-dkms.sh. Re-enable the COPR that
# common/core/060-cachyos-kernel.sh already disabled.
dnf5 -y copr enable bieszczaders/kernel-cachyos
dnf5 -y install --enablerepo="copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos" \
    dkms gcc make git kernel-cachyos-devel-matched sbsigntools openssl

# LOOKING_GLASS_TAG/KVMFR_VERSION pinned in build_files/versions-frequent-desktop.sh.
git clone --quiet --depth 1 --branch "$LOOKING_GLASS_TAG" \
    https://github.com/gnif/LookingGlass.git /tmp/looking-glass

KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-cachyos-core)"

source /ctx/lib/sign-helpers.sh
configure_dkms_signing
if ! mok_signing_available; then
    echo "No MOK key supplied — kvmfr module is unsigned."
fi

rm -rf "/usr/src/kvmfr-${KVMFR_VERSION}"
cp -a /tmp/looking-glass/module "/usr/src/kvmfr-${KVMFR_VERSION}"
dkms add -m kvmfr -v "$KVMFR_VERSION"
dkms build -m kvmfr -v "$KVMFR_VERSION" -k "$KVER"
dkms install -m kvmfr -v "$KVMFR_VERSION" -k "$KVER" --force
# Belt-and-suspenders: never leave a DKMS-generated signing key in the image.
rm -f /var/lib/dkms/mok.key /var/lib/dkms/mok.pub

# Allow the kvm group to access the kvmfr device (user must be in the kvm group)
install -Dm644 /dev/null /usr/lib/udev/rules.d/99-kvmfr.rules
printf 'SUBSYSTEM=="kvmfr", OWNER="root", GROUP="kvm", MODE="0660"\n' \
    > /usr/lib/udev/rules.d/99-kvmfr.rules

dnf5 -y remove --noautoremove dkms gcc make sbsigntools kernel-cachyos-devel-matched
dnf5 -y copr disable bieszczaders/kernel-cachyos
rm -rf /tmp/looking-glass

# Module is already installed under /usr/lib/modules/$KVER; DKMS's own
# build cache here is unneeded and bootc lint flags unmanaged /var content.
rm -rf /var/lib/dkms/kvmfr "/usr/src/kvmfr-${KVMFR_VERSION}"

### VFIO
# Enabled in enable-services.sh, not here — systemctl is still stubbed out
# at this point in the build (see phase-setup.sh).

# dracut.conf.d/99-vfio.conf is picked up by phase-finalize.sh's initramfs regen.
