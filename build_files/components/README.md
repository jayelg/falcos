[root](../../README.md) / [build_files](../README.md) / **components**

Self-describing, independently cacheable build units. Each component runs in its own Containerfile RUN layer. Toggleable via [COMPONENTS.list](../../COMPONENTS.list).

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
- `cachyos-kernel` -- CachyOS kernel + companions + module signing

### Hardware (`hardware/`)
- `firmware` -- iwlwifi firmware
- `gaming` -- xone driver + gamemode
- `tools` -- alsa-ucm, dmidecode, intel-lpmd, lm_sensors, etc.

### Multimedia (`multimedia/`)
- `multimedia` -- negativo17 codec overrides, ffmpeg, pipewire-extra

### Networking (`networking/`)
- `networking` -- avahi, wireguard-tools, tcpdump, etc.

### Virtualization (`virtualization/`)
- `libvirt` -- libvirt, qemu, virt-manager, virt-viewer
- `incus` -- incus, lxc, systemd-container
- `podman` -- podman-compose, podman-machine, podman-tui

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
