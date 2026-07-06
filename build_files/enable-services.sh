### Enable services
# Grouped by which common/*.sh installed the corresponding package. Must run
# after systemctl is restored to the real binary (phase-finalize.sh), not
# while the install-time stub is in place.

# sshd ships enabled via the base image's systemd-preset (server/IoT
# default). Disabled, not masked, for this single-user hardened image —
# still available via `systemctl enable` if wanted.
systemctl disable sshd.service

# common/core/050-bootloader.sh — grub2-os-prober-regen is NOT run
# automatically (see build_files/files/common/usr/libexec/grub2-os-prober-regen
# for why); it's an on-demand `sudo /usr/libexec/grub2-os-prober-regen`
# command instead, matching how Bazzite's own equivalent (`ujust
# regenerate-grub`) is also manual rather than an automatic unit.

# common/core/010-kde-desktop.sh (kde-desktop group + its own installs)
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

# Desktop-only unit (build_files/desktop.sh), absent on laptop — gated on
# presence since this script runs for both. Enabled here rather than in
# desktop.sh because systemctl is still stubbed out at that point.
if [ -f /usr/lib/systemd/system/vfio-rebind-gpu-usb.service ]; then
    systemctl enable vfio-rebind-gpu-usb.service
fi

# common/core/120-security.sh
systemctl enable pcscd.socket

# common/core/130-hardening.sh — unbound+dnsconfd replace systemd-resolved.
systemctl mask systemd-resolved.service
systemctl enable unbound.service
systemctl enable dnsconfd.service

# common/core/160-greenboot.sh — NOT enabled for now. GRUB's boot_counter
# fallback (meant to be folded into grub.cfg via bootupd) isn't confirmed
# wired up on real hardware; without it, a red boot retries forever instead
# of ever falling back, which is worse than no health-checking at all.
# Package and custom checks stay installed so re-enabling later is a
# one-line change once the bootupd/GRUB gap is understood and verified in
# a VM first.
# systemctl enable greenboot-healthcheck.service

# First-boot setup and automatic updates (files/common, no dnf5 install)
systemctl enable install-default-flatpaks.service
systemctl --global enable brew-setup.service
systemctl --global enable seed-justfile.service
systemctl enable bootc-fetch-apply-updates.timer
systemctl enable flatpak-update.timer
systemctl --global enable update-notify.timer
