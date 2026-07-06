### xone — Xbox Wireless Adapter driver
# Built via DKMS against kernel-cachyos-devel-matched rather than the
# `akmods` wrapper, which assumes a running kernel and doesn't work mid
# container-build. 060-cachyos-kernel.sh already disabled this COPR;
# re-enable since kernel-cachyos-devel-matched only exists in it.
dnf5 -y copr enable bieszczaders/kernel-cachyos
dnf5 -y install --enablerepo="copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos" \
    dkms gcc make git kernel-cachyos-devel-matched sbsigntools openssl cabextract

# XONE_COMMIT pinned in build_files/versions-core-kernel.sh (upstream's tags stop
# at v0.3 and are stale).
XONE_VERSION="0.0.0+${XONE_COMMIT:0:12}"

git clone --quiet https://github.com/medusalix/xone.git /tmp/xone
git -C /tmp/xone checkout --quiet "$XONE_COMMIT"

sed -i "s/#VERSION#/${XONE_VERSION}/g" /tmp/xone/dkms.conf

KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-cachyos-core)"

source /ctx/lib/sign-helpers.sh
configure_dkms_signing
if ! mok_signing_available; then
    echo "No MOK key supplied — xone modules are unsigned."
fi

rm -rf "/usr/src/xone-${XONE_VERSION}"
cp -a /tmp/xone "/usr/src/xone-${XONE_VERSION}"
dkms add -m xone -v "$XONE_VERSION"
dkms build -m xone -v "$XONE_VERSION" -k "$KVER"
dkms install -m xone -v "$XONE_VERSION" -k "$KVER" --force
# Belt-and-suspenders: never leave a DKMS-generated signing key in the image.
rm -f /var/lib/dkms/mok.key /var/lib/dkms/mok.pub

# Stops the in-tree xpad/mt76x2u drivers from fighting xone for the same USB IDs.
install -D -m 0644 /tmp/xone/install/modprobe.conf /usr/lib/modprobe.d/xone-blacklist.conf

# Proprietary Xbox Wireless Adapter dongle firmware, subject to Microsoft's
# Terms of Use (https://www.microsoft.com/en-us/legal/terms-of-use);
# --skip-disclaimer accepts non-interactively at build time.
sh /tmp/xone/install/firmware.sh --skip-disclaimer

dnf5 -y remove --noautoremove dkms gcc make sbsigntools kernel-cachyos-devel-matched
dnf5 -y copr disable bieszczaders/kernel-cachyos
rm -rf /tmp/xone

# Modules are already installed under /usr/lib/modules/$KVER; DKMS's own
# build cache here is unneeded and bootc lint flags unmanaged /var content.
rm -rf /var/lib/dkms/xone "/usr/src/xone-${XONE_VERSION}"
