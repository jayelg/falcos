[root](../../README.md) / [build_files](../README.md) / **components**

Self-describing, independently cacheable build units. Each component runs in its own Containerfile RUN layer via [lib/run-component.sh](../lib/run-component.sh), and is toggled/ordered by [COMPONENTS.list](../../COMPONENTS.list). Editing the list is enough: `just build` and CI regenerate the Containerfile section from it automatically. A component is any bake-in unit — an app install, a kernel swap, or just a directory drop; create a directory here (any of the optional pieces below) and add its name to the list.

### Anatomy of a component

```
components/<group>/<name>/
  component.sh        the install logic; sourced with pins loaded (optional --
                      omit for a pure-file component that only drops files/)
  versions.sh         Renovate-tracked version pins + SHA256s (optional)
  repo                package repo setup, idempotent via REPO_ID (optional)
  selinux/*.te        local SELinux policy modules, each auto-compiled and
                      installed at priority 200 (optional)
  files/              overlay copied verbatim into the image, including any
                      usr/lib/systemd/*-preset/45-falcos-<name>.preset files
                      that 99-finalize.sh applies (optional)
  finalize.sh         run-once logic needing real systemctl or the final
                      image (e.g. service masking, policy.json edits), sourced
                      by 99-finalize.sh in list order and flavor-gated (optional)
  justfile.inc        falcos-cli app recipes, appended at build time (optional)
  variants/<v>.sh     pin/flag overrides, selected as <name>@<v> in the list (optional)
  Containerfile.part  verbatim RUN block when the standard one isn't enough,
                      e.g. build secrets or ARGs (optional)
```

The directory name is the component name in COMPONENTS.list and must be unique across all groups.

To start a new component, copy [`_template/component-name/`](_template) — a copy-me reference that demonstrates every capability above (helpers, preset, finalize.sh, variants, Containerfile.part, SELinux) with a walkthrough README in [`_template/`](_template). It is not listed in COMPONENTS.list, so it never builds.

### Base (`base/`) -- do not disable
- `base` -- pure-file base-system layer: sshd-off preset, coredump lockdown, PAM policy (faillock/pwquality), sulogin generator, os-release logo + plymouth branding

### Desktop Environment (`de/`)
- `kde-desktop` -- KDE Plasma Desktop group install, apps, krunner-bazaar
- `kde-theming` -- Darkly, Ant, AWW, papirus icons
- `falcos-plasma-settings` -- bootc-updates KDE System Settings module + notifier (installs after kde-desktop)
- `plasma-network-audio` -- Plasma network/audio settings module

### Core System (`core/`) -- do not disable
- `auto-updates` -- staged bootc auto-update timer + sigstore signature policy (pure-file + finalize.sh)
- `falcos-tools` -- falcos-cli OS TUI + `just` justfile engine + fastfetch (KDE-independent CLI framework)
- `flatpak` -- flatpak client + first-boot default apps + daily update timer
- `brew` -- Homebrew first-login setup + PATH shim
- `cli-tools` -- traditional CLI utilities (tmux, htop, rsync, vim, etc.)
- `cli-customizations` -- opinionated shell UX: bat/eza/ripgrep/fd/ugrep/zoxide/gum, starship, flyline, aichat, Nerd Fonts + zz-bling aliases
- `dev-tools` -- git, direnv, git-delta, etc.
- `manage-dotfiles` -- chezmoi + Bitwarden CLI + the `setup-dotfiles` recipe

### Kernel (`kernel/`)
- `cachyos-kernel` -- CachyOS kernel + companions + module signing (KERNEL=stock build arg keeps the Fedora kernel)

### Hardware (`hardware/`)
- `intel-wifi` -- Intel WiFi firmware (iwlwifi)
- `gaming` -- xone driver + gamemode
- `hardware-tools` -- alsa-ucm, dmidecode, intel-lpmd, lm_sensors, etc.
- `logitech` -- Solaar udev rules for Logitech wireless peripherals
- `yubikey` -- hardware token / smartcard auth stack (YubiKey, FIDO2, PAM, PC/SC)
- `laptop-tweaks` -- s2idle sleep karg (laptop flavor only)

### Multimedia (`multimedia/`)
- `multimedia` -- negativo17 codec overrides, ffmpeg, pipewire-extra

### Networking (`networking/`)
- `networking` -- avahi, wireguard-tools, tcpdump, etc.

### Virtualization (`virtualization/`)
- `libvirt` -- libvirt, qemu, virt-manager, virt-viewer
- `incus` -- incus, lxc, systemd-container
- `podman` -- podman-compose, podman-machine, podman-tui
- `vfio-passthrough` -- VFIO kargs, modprobe binds, dracut + GPU/USB rebind service (desktop flavor only)
- `looking-glass` -- kvmfr DKMS module for GPU passthrough (desktop flavor only)

### Backup (`backup/`)
- `backup-tools` -- borgbackup, rclone, restic

### Hardening (`hardening/`)
- `hardened-malloc` -- hardened_malloc + no_rlimit_as
- `sudo-hardening` -- sudoers.d/99-hardening

### Desktop Applications (`apps/`)
- `affinity` -- Affinity Photo/Designer/Publisher via Wine
- `trivalent` -- secureblue's hardened Chromium fork
- `vscodium` -- VSCodium (telemetry-free VS Code), hardened_malloc-exempt wrapped

### VPN (`vpn/`)
- `mullvad-vpn` -- Mullvad VPN daemon
- `netbird` -- Netbird mesh VPN
- `tailscale` -- Tailscale mesh VPN
