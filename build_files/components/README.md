[root](../../README.md) / [build_files](../README.md) / **components**

Self-describing, independently cacheable build units. Each component runs in its own Containerfile RUN layer via [lib/run-component.sh](../lib/run-component.sh), and is toggled/ordered by [COMPONENTS.list](../../COMPONENTS.list). Editing the list is enough: `just build` and CI regenerate the Containerfile section from it automatically. To add a component, create a directory here (component.sh plus whatever optional files below) and add its name to the list.

### Anatomy of a component

```
components/<group>/<name>/
  component.sh        the install logic (required); sourced with pins loaded
  versions.sh         Renovate-tracked version pins + SHA256s (optional)
  repo                package repo setup, idempotent via REPO_ID (optional)
  files/              overlay copied verbatim into the image, including any
                      usr/lib/systemd/*-preset/45-falcos-<name>.preset files
                      that phase-finalize.sh applies (optional)
  justfile.inc        falcos-cli app recipes, appended at build time (optional)
  variants/<v>.sh     pin/flag overrides, selected as <name>@<v> in the list (optional)
  Containerfile.part  verbatim RUN block when the standard one isn't enough,
                      e.g. build secrets or ARGs (optional)
```

The directory name is the component name in COMPONENTS.list and must be unique across all groups.

### Desktop Environment (`de/`)
- `kde-desktop` -- KDE Plasma Desktop group install, apps, krunner-bazaar
- `kde-theming` -- Darkly, Ant, AWW, papirus icons
- `plasma-network-audio` -- Plasma network/audio settings module

### Core System (`core/`) -- do not disable
- `cli-tools` -- bat, eza, ripgrep, tmux, zoxide, etc.
- `dev-tools` -- git, just, direnv, gum, etc.
- `falcos-bootc-updates` -- bootc update automation
- `pinned-cli-tools` -- VSCodium, falcos-cli, Nerd Fonts, etc.

### Kernel (`kernel/`)
- `cachyos-kernel` -- CachyOS kernel + companions + module signing (KERNEL=stock build arg keeps the Fedora kernel)

### Hardware (`hardware/`)
- `firmware` -- iwlwifi firmware
- `gaming` -- xone driver + gamemode
- `hardware-tools` -- alsa-ucm, dmidecode, intel-lpmd, lm_sensors, etc.

### Multimedia (`multimedia/`)
- `multimedia` -- negativo17 codec overrides, ffmpeg, pipewire-extra

### Networking (`networking/`)
- `networking` -- avahi, wireguard-tools, tcpdump, etc.

### Virtualization (`virtualization/`)
- `libvirt` -- libvirt, qemu, virt-manager, virt-viewer
- `incus` -- incus, lxc, systemd-container
- `podman` -- podman-compose, podman-machine, podman-tui
- `looking-glass` -- kvmfr DKMS module for GPU passthrough (desktop flavor only)

### Security (`security/`)
- `security` -- borg, rclone, restic, yubikey, pam-u2f

### Hardening (`hardening/`)
- `hardened-malloc` -- hardened_malloc + no_rlimit_as
- `sudo-hardening` -- sudoers.d/99-hardening

### Desktop Applications (`apps/`)
- `affinity` -- Affinity Photo/Designer/Publisher via Wine
- `trivalent` -- secureblue's hardened Chromium fork

### VPN (`vpn/`)
- `mullvad-vpn` -- Mullvad VPN daemon
- `netbird` -- Netbird mesh VPN
- `tailscale` -- Tailscale mesh VPN
