### Hardware & performance
HARDWARE_PACKAGES=(
    alsa-ucm            # ALSA Use Case Manager configs (device-specific audio routing)
    alsa-utils
    dmidecode           # read hardware info from the BIOS/DMI tables
    gamemode
    intel-lpmd          # Intel Low Power Mode Daemon (Intel CPUs only, e.g. the laptop)
    lm_sensors
    lshw
    pciutils
    powerstat           # power consumption sampling
)
dnf5 install -y "${HARDWARE_PACKAGES[@]}"

### Firmware
FIRMWARE_PACKAGES=(
    iwlwifi-mvm-firmware   # Intel WiFi 6/6E (AX200/AX210)
    iwlwifi-mld-firmware   # Intel WiFi 7 (BE200/BE202 and newer)
)
dnf5 install -y "${FIRMWARE_PACKAGES[@]}"

### xone Xbox Wireless Adapter driver
# Built via DKMS, the akmods wrapper assumes a running kernel and doesn't
# work mid container build.
source /ctx/lib/kernel-helpers.sh
kernel_devel_install dkms gcc make git sbsigntools openssl cabextract

XONE_VERSION="0.0.0+${XONE_COMMIT:0:12}"

git clone --quiet https://github.com/medusalix/xone.git /tmp/xone
git -C /tmp/xone checkout --quiet "$XONE_COMMIT"

sed -i "s/#VERSION#/${XONE_VERSION}/g" /tmp/xone/dkms.conf

KVER="$(kver)"

source /ctx/lib/sign-helpers.sh
configure_dkms_signing
if ! mok_signing_available; then
    echo "No MOK key supplied, xone modules are unsigned."
fi

rm -rf "/usr/src/xone-${XONE_VERSION}"
cp -a /tmp/xone "/usr/src/xone-${XONE_VERSION}"
dkms add -m xone -v "$XONE_VERSION"
dkms build -m xone -v "$XONE_VERSION" -k "$KVER"
dkms install -m xone -v "$XONE_VERSION" -k "$KVER" --force
# Never leave a DKMS-generated signing key in the image
rm -f /var/lib/dkms/mok.key /var/lib/dkms/mok.pub

# Stop the in-tree xpad/mt76x2u drivers claiming the same USB IDs
install -D -m 0644 /tmp/xone/install/modprobe.conf /usr/lib/modprobe.d/xone-blacklist.conf

# Proprietary dongle firmware, subject to Microsoft's Terms of Use;
# --skip-disclaimer accepts non-interactively at build time.
sh /tmp/xone/install/firmware.sh --skip-disclaimer

kernel_devel_remove dkms gcc make sbsigntools
rm -rf /tmp/xone

# bootc lint flags the leftover DKMS build cache as unmanaged /var content
rm -rf /var/lib/dkms/xone "/usr/src/xone-${XONE_VERSION}"

### Not yet implemented
# ZFS filesystem support, kmod build is incompatible with container builds
