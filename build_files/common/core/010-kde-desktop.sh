### KDE Plasma Desktop
dnf5 group install -y kde-desktop

# The bare kde-desktop group doesn't pull networkmanager-submodules (only the
# full kde-desktop-environment does) — without it, wpa_supplicant and
# NetworkManager-wifi are both missing, so WiFi doesn't work at all. Also
# covers dnsmasq (libvirt's default NAT network needs it too).
dnf5 group install -y networkmanager-submodules

# Trim defaults not worth keeping
dnf5 remove -y --noautoremove \
    abrt abrt-addon-ccpp abrt-addon-kerneloops abrt-addon-pstoreoops \
    abrt-addon-vmcore abrt-addon-xorg abrt-dbus abrt-desktop abrt-gui \
    abrt-plugin-bodhi gnome-abrt \
    PackageKit PackageKit-command-not-found PackageKit-glib \
    plasma-discover plasma-discover-libs plasma-discover-packagekit \
    plasma-discover-offline-updates \
    sssd-ad sssd-common-pac sssd-ipa sssd-krb5 sssd-ldap \
    kdump-utils kexec-tools makedumpfile \
    qemu-user-static-alpha qemu-user-static-arm qemu-user-static-hexagon \
    qemu-user-static-hppa qemu-user-static-loongarch64 qemu-user-static-m68k \
    qemu-user-static-microblaze qemu-user-static-mips qemu-user-static-or1k \
    qemu-user-static-ppc qemu-user-static-riscv qemu-user-static-s390x \
    qemu-user-static-sh4 qemu-user-static-sparc qemu-user-static-x86 \
    qemu-user-static-xtensa \
    NetworkManager-l2tp NetworkManager-libreswan NetworkManager-pptp \
    NetworkManager-cloud-setup NetworkManager-tui \
    plasma-nm-l2tp plasma-nm-openswan plasma-nm-pptp

# Browser itself lives in common/frequent/030-browser.sh — it updates far
# too often, unpinned, to sit in this (cached) layer. Generic KDE browser
# integration stays here since it's not tied to any specific browser.
dnf5 install -y plasma-browser-integration

# Plain spinner theme, no OEM firmware-logo background. Watermark blanked
# via the files/common override.
dnf5 install -y plymouth plymouth-theme-spinner
plymouth-set-default-theme spinner

# KDE apps & desktop integration
KDE_PACKAGES=(
    gvfs
    gvfs-client
    gvfs-fuse                     # FUSE mount for gvfs backends, for apps that can't use gvfs natively
    input-remapper                # remap keyboard/mouse/gamepad buttons
    kamera                        # KDE camera/webcam import integration
    kate
    kate-krunner-plugin           # search open Kate documents from KRunner
    kate-plugins
    ksystemlog                    # GUI system log viewer
    plasma-firewall               # KDE firewall settings UI
    plasma-firewall-firewalld     # firewalld backend for plasma-firewall
)
dnf5 install -y "${KDE_PACKAGES[@]}"
