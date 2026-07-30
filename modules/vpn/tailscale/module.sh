# Tailscale mesh VPN
dnf5 install -y --enablerepo='tailscale-stable' tailscale

# systemd-resolved ships /usr/sbin/resolvconf as a resolvectl shim that doesn't
# behave like real resolvconf/openresolv. tailscaled misdetects it as the DNS
# manager, writes /etc/resolv.conf directly with its own marker, then reads that
# same marker back on every future start and never probes systemd-resolved
# properly (see tailscale/tailscale#19062). Remove the shim so tailscaled falls
# back to the systemd-resolved D-Bus API.
rm -f /usr/sbin/resolvconf /usr/bin/resolvconf
