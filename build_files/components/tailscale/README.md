# Tailscale

Tailscale mesh VPN, installed from the tailscale-stable COPR repo enabled
in core/000-repos.sh. Not version-pinned, follows the distro. Removes the
systemd-resolved `resolvconf` shim at install time so tailscaled falls back
to the systemd-resolved D-Bus API instead of misdetecting it as a DNS manager.

## Build

At image build time:
- `dnf5 install -y --enablerepo='tailscale-stable' tailscale`
- `rm -f /usr/sbin/resolvconf /usr/bin/resolvconf`

## Files installed

- Tailscale packages from the tailscale-stable COPR repo

## Runtime

Run `sudo tailscale up` to authenticate and connect.
