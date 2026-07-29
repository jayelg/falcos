# Tailscale

Tailscale mesh VPN, installed from the tailscale-stable repo (configured by `repo`, enabled=0). Not version-pinned, follows the distro. Removes the systemd-resolved `resolvconf` shim at install time so tailscaled falls back to the systemd-resolved D-Bus API.
