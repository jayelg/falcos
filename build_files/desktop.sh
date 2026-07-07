### Looking Glass kvmfr module (shared-memory transport between host and VM)
dnf5 -y copr enable bieszczaders/kernel-cachyos
dnf5 -y install --enablerepo="copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos" \
    dkms gcc make git kernel-cachyos-devel-matched sbsigntools openssl

git clone --quiet --depth 1 --branch "$LOOKING_GLASS_TAG" \
    https://github.com/gnif/LookingGlass.git /tmp/looking-glass

KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-cachyos-core)"

source /ctx/lib/sign-helpers.sh
configure_dkms_signing
if ! mok_signing_available; then
    echo "No MOK key supplied, kvmfr module is unsigned."
fi

rm -rf "/usr/src/kvmfr-${KVMFR_VERSION}"
cp -a /tmp/looking-glass/module "/usr/src/kvmfr-${KVMFR_VERSION}"
dkms add -m kvmfr -v "$KVMFR_VERSION"
dkms build -m kvmfr -v "$KVMFR_VERSION" -k "$KVER"
dkms install -m kvmfr -v "$KVMFR_VERSION" -k "$KVER" --force
# Never leave a DKMS-generated signing key in the image
rm -f /var/lib/dkms/mok.key /var/lib/dkms/mok.pub

# Allow the kvm group to access the kvmfr device (user must be in the kvm group)
install -Dm644 /dev/null /usr/lib/udev/rules.d/99-kvmfr.rules
printf 'SUBSYSTEM=="kvmfr", OWNER="root", GROUP="kvm", MODE="0660"\n' \
    > /usr/lib/udev/rules.d/99-kvmfr.rules

dnf5 -y remove --noautoremove dkms gcc make sbsigntools kernel-cachyos-devel-matched
dnf5 -y copr disable bieszczaders/kernel-cachyos
rm -rf /tmp/looking-glass

# bootc lint flags the leftover DKMS build cache as unmanaged /var content
rm -rf /var/lib/dkms/kvmfr "/usr/src/kvmfr-${KVMFR_VERSION}"

### VFIO
# The vfio-rebind-gpu-usb unit is enabled in enable-services.sh and
# dracut.conf.d/99-vfio.conf is picked up by phase-finalize.sh's initramfs regen.
