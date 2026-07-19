# Mullvad VPN

Mullvad VPN daemon, installed from the Mullvad COPR repo enabled in
core/000-repos.sh. Not version-pinned, follows the distro.

## Build

At image build time:
- `dnf5 install -y mullvad-vpn`

## Files installed

- Mullvad VPN packages from the Mullvad COPR repo

## Runtime

No user setup required. Launch from the application menu.
