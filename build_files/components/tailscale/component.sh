# Tailscale mesh VPN
# Phase: frequent
# Priority: 010 (early, VPN daemons)
# Writable paths: /usr (dnf5-installed packages)

COMPDIR="$(dirname "${BASH_SOURCE[0]}")"
COMPONENT_VERSION="${COMPONENT_VERSION:-latest}"
if [ -d "$COMPDIR/$COMPONENT_VERSION" ]; then
    COMPDIR="$COMPDIR/$COMPONENT_VERSION"
fi

dnf5 install -y --enablerepo='tailscale-stable' tailscale

# systemd-resolved ships /usr/sbin/resolvconf as a resolvectl shim that doesn't
# behave like real resolvconf/openresolv. tailscaled misdetects it as the DNS
# manager, writes /etc/resolv.conf directly with its own marker, then reads that
# same marker back on every future start and never probes systemd-resolved
# properly (see tailscale/tailscale#19062). Remove the shim so tailscaled falls
# back to the systemd-resolved D-Bus API.
rm -f /usr/sbin/resolvconf /usr/bin/resolvconf

[ -d "$COMPDIR/files" ] && cp -rT "$COMPDIR/files" "/"
if [ -f "$COMPDIR/justfile.inc" ]; then
    cat "$COMPDIR/justfile.inc" >> /usr/share/falcos/justfile.apps
fi
