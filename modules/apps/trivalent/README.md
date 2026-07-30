# Trivalent

secureblue's hardened Chromium fork. Has its own hardened_malloc integration
so it needs no LD_PRELOAD exemption. Not version-pinned, upstream ships new
builds continuously.

## Build

At image build time:
- `dnf5 install -y --enablerepo='secureblue' trivalent trivalent-qt6-ui trivalent-selinux`
- Installs a local SELinux policy supplement for bwrap fallback sandbox rules.

## Files installed

- Trivalent packages from the secureblue repo
- SELinux module `trivalent_local_fixes`

## Runtime

No user setup required. Launch from the application menu.
