[root](../../../README.md) / [build_files](../../README.md) / [common](../README.md) / **core**

Foundational setup shared by both flavors. Each script is sourced by phase-core.sh in build order (the numeric prefix). Version pins come from the `versions-core-*.sh` files. Scripts that build kernel modules use the [Signing Helpers](../../lib) for optional Secure Boot signing.

## Scripts in run order:

- [Repositories](000-repos.sh)

- [KDE Desktop](010-kde-desktop.sh)

- [KDE Theming](020-kde-theming.sh)

- [CLI Tools](030-cli-tools.sh)

- [Dev Tools](040-dev-tools.sh)

- [Bootloader](050-bootloader.sh)

- [Kernel](060-kernel.sh)

- [Hardware](070-hardware.sh)

- [Multimedia](090-multimedia.sh)

- [Networking](100-networking.sh)

- [Virtualization](110-virtualization.sh)

- [Security](120-security.sh)

- [Hardening](130-hardening.sh)

- [SELinux](140-selinux.sh)

- [COPR Extras](150-copr-extras.sh)

## Notes / Todo
