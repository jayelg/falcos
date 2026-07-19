# Netbird

Netbird mesh VPN, installed from the Netbird COPR repo enabled in
core/000-repos.sh. Not version-pinned, follows the distro.

## Build

At image build time:
- `dnf5 install -y netbird`

## Files installed

- Netbird packages from the Netbird COPR repo

## Runtime

No user setup required for the daemon. Configure via `netbird` CLI.
