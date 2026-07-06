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

### Not yet implemented
# ZFS filesystem support — kmod build incompatible with container builds
# (xone Xbox controller support moved to common/core/080-xone-dkms.sh — DKMS
# works fine here, it's the `akmods` wrapper that assumes a running kernel)
