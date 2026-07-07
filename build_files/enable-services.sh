### Enable services
# Grouped by which script installed the package. Runs from
# phase-finalize.sh after systemctl is restored.

# Base image preset enables sshd, not wanted on a single-user desktop
systemctl disable sshd.service

# common/core/010-kde-desktop.sh
systemctl enable plasmalogin-shadow-workaround.service
systemctl enable plasmalogin.service
systemctl enable plasma-setup.service
systemctl enable accounts-daemon.service
systemctl enable firewalld.service
systemctl enable tuned.service
systemctl enable tuned-ppd.service
systemctl enable thermald.service
systemctl enable switcheroo-control.service
systemctl enable input-remapper
systemctl --global enable wireplumber.service
systemctl --global enable pipewire-pulse.socket

# common/core/070-hardware.sh
systemctl enable lm_sensors.service
systemctl enable intel_lpmd.service

# common/frequent/010-vpn.sh
systemctl enable mullvad-daemon
systemctl enable netbird
systemctl enable tailscaled

# common/core/110-virtualization.sh
systemctl enable podman.socket
systemctl enable libvirtd.socket
systemctl enable libvirt-relabel.service
systemctl enable libvirt-group-membership.service

# Desktop-only unit, absent on laptop
if [ -f /usr/lib/systemd/system/vfio-rebind-gpu-usb.service ]; then
    systemctl enable vfio-rebind-gpu-usb.service
fi

# common/core/120-security.sh
systemctl enable pcscd.socket

# First-boot setup and automatic updates (files/common, no dnf5 install)
systemctl enable install-default-flatpaks.service
systemctl --global enable brew-setup.service
systemctl --global enable seed-justfile.service
systemctl enable bootc-fetch-apply-updates.timer
systemctl enable flatpak-update.timer
systemctl --global enable update-notify.timer
