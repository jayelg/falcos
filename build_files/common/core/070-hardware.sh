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
source /ctx/lib/dkms-helpers.sh
kernel_devel_install "${DKMS_BUILD_DEPS[@]}" cabextract

XONE_VERSION="0.0.0+${XONE_COMMIT:0:12}"

git clone --quiet https://github.com/medusalix/xone.git /tmp/xone
git -C /tmp/xone checkout --quiet "$XONE_COMMIT"

sed -i "s/#VERSION#/${XONE_VERSION}/g" /tmp/xone/dkms.conf

dkms_build_module xone "$XONE_VERSION" /tmp/xone

# Stop the in-tree xpad/mt76x2u drivers claiming the same USB IDs
install -D -m 0644 /tmp/xone/install/modprobe.conf /usr/lib/modprobe.d/xone-blacklist.conf

# Proprietary dongle firmware, subject to Microsoft's Terms of Use;
# --skip-disclaimer accepts non-interactively at build time.
sh /tmp/xone/install/firmware.sh --skip-disclaimer

# cabextract comes back later as a winetricks dependency (needed at runtime
# by affinity-setup); removing it here keeps its presence dependency-owned
kernel_devel_remove "${DKMS_BUILD_DEPS_REMOVE[@]}" cabextract
rm -rf /tmp/xone

### Not yet implemented
# ZFS filesystem support, kmod build is incompatible with container builds
