### Enable services
# Grouped by which component installed the package. Runs from
# phase-finalize.sh after systemctl is restored.

# Base image preset enables sshd, not wanted on a single-user desktop
systemctl disable sshd.service

# Fedora countme telemetry, off for this image. Only the timer is masked so
# `rpm-ostree countme` still works manually. The timer elapses during sleep
# and fires on resume before the network is up, leaving a failed unit; if
# unmasked, the rpm-ostree-countme.service.d drop-in adds retries for that.
systemctl mask rpm-ostree-countme.timer

# components/de/kde-desktop/component.sh
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

# components/hardware/tools/component.sh
systemctl enable lm_sensors.service
systemctl enable intel_lpmd.service

# components/vpn/mullvad-vpn/component.sh, components/vpn/netbird/component.sh, components/vpn/tailscale/component.sh
systemctl enable mullvad-daemon
systemctl enable netbird
systemctl enable tailscaled

# components/virtualization/libvirt/component.sh
systemctl enable libvirtd.socket
systemctl enable libvirt-relabel.service
systemctl enable libvirt-group-membership.service

# components/virtualization/podman/component.sh
systemctl enable podman.socket

# Desktop-only unit, absent on laptop
if [ -f /usr/lib/systemd/system/vfio-rebind-gpu-usb.service ]; then
    systemctl enable vfio-rebind-gpu-usb.service
fi

# components/security/component.sh
systemctl enable pcscd.socket

# First-boot setup and automatic updates (files/common, no dnf5 install)
systemctl enable install-default-flatpaks.service
systemctl --global enable brew-setup.service
systemctl --global enable affinity-sync.service
systemctl enable bootc-fetch-apply-updates.timer
systemctl enable flatpak-update.timer
