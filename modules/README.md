[root](../../README.md) / [build-phases](../README.md) / **modules**

Self-describing, independently cacheable build units. Every module carries a [module.kdl](SCHEMA.md) manifest declaring what it needs from the rest of the image and what it offers back; everything else about a module is discovered from the files it ships. Each module runs in its own Containerfile RUN layer via [lib/run-module.sh](../lib/run-module.sh), is enabled by [modules.kdl](../../modules.kdl), and builds in the order the declared graph resolves to, with the list as the tie-break. Editing the list is enough: `just build` and CI regenerate the Containerfile section from it automatically. A module is any bake-in unit — an app install, a kernel swap, or just a directory drop; create a directory here (any of the optional pieces below) and add its path to the list.

### Anatomy of a module

```
modules/<group-or-name>/<name>/
  module.kdl          the manifest: what this module needs, offers and
                      accepts. REQUIRED. See SCHEMA.md
  module.sh           the install logic; sourced with pins loaded (optional --
                      omit for a pure-file module that only drops files/)
  versions.sh         Renovate-tracked version pins + SHA256s (optional)
  repo                package repo setup, idempotent via REPO_ID (optional)
  selinux/*.te        local SELinux policy modules, each auto-compiled and
                      installed at priority 200 (optional)
  files/              overlay copied verbatim into the image, including any
                      usr/lib/systemd/*-preset/45-falcos-<name>.preset files
                      that 99-finalize.sh applies (optional)
  finalize.sh         run-once logic needing real systemctl or the final
                      image (e.g. service masking, policy.json edits), sourced
                      by 99-finalize.sh in build order and flavor-gated (optional)
  justfile.inc        goojust app recipes, collected at build time by
                      core/goojust, which declares where they go (optional)
  Containerfile.inc   verbatim Containerfile lines added above the generated
                      block, for what the fields can't express, e.g. an ARG
                      with a default (optional)
```

The directory name is the module name in modules.kdl. Modules are organized into group subdirectories (e.g. `core/`, `de/`, `hardware/`) or live directly under `modules/`. The entry in modules.kdl is the path relative to `modules/` — e.g. `core/auto-updates` for `modules/core/auto-updates/`.

To start a new module, copy [`_template/module-name/`](_template/module-name) — a copy-me reference that demonstrates every capability above (manifest, helpers, preset, finalize.sh, options, Containerfile.inc, SELinux) with a walkthrough README in [`_template/`](_template). It is not listed in modules.kdl, so it never builds.

### Base (`base/`) -- do not disable
- `base` -- pure-file base-system layer: sshd-off preset, coredump lockdown, PAM policy (faillock/pwquality), sulogin generator, os-release logo + plymouth branding

### Desktop Environment (`de/`)
- `de/kde-desktop` -- KDE Plasma Desktop group install, apps, krunner-bazaar
- `de/kde-theming` -- Darkly, Ant, AWW, papirus icons
- `de/falcos-plasma-settings` -- bootc-updates KDE System Settings module + notifier (installs after kde-desktop)
- `de/plasma-network-audio` -- Plasma network/audio settings module

### Core System (`core/`) -- do not disable
- `core/auto-updates` -- staged bootc auto-update timer + sigstore signature policy (pure-file + finalize.sh)
- `core/goojust` -- goojust OS TUI + `just` justfile engine + fastfetch (KDE-independent CLI framework)
- `core/flatpak` -- flatpak client + first-boot default apps + daily update timer
- `core/brew` -- Homebrew first-login setup + PATH shim
- `core/cli-tools` -- traditional CLI utilities (tmux, htop, rsync, vim, etc.)

### Kernel (`kernel/`)
- `kernel/cachyos-kernel` -- CachyOS kernel + companions + module signing (KERNEL=stock build arg keeps the Fedora kernel)

### Hardware (`hardware/`)
- `hardware/intel-wifi` -- Intel WiFi firmware (iwlwifi)
- `hardware/gaming` -- xone driver + gamemode
- `hardware/hardware-tools` -- alsa-ucm, dmidecode, intel-lpmd, lm_sensors, etc.
- `hardware/logitech` -- Solaar udev rules for Logitech wireless peripherals
- `hardware/yubikey` -- hardware token / smartcard auth stack (YubiKey, FIDO2, PAM, PC/SC)
- `hardware/laptop-tweaks` -- s2idle sleep karg (laptop flavor only)

### Media Codecs (`media-codecs/`)
- `media-codecs` -- negativo17 codec overrides, ffmpeg, pipewire-extra

### CLI & User Setup (`cli-customizations/`, `manage-dotfiles/`)
- `cli-customizations` -- opinionated shell UX: bat/eza/ripgrep/fd/ugrep/zoxide/gum, starship, flyline, aichat, Nerd Fonts + zz-bling aliases
- `manage-dotfiles` -- chezmoi + Bitwarden CLI + the `setup-dotfiles` recipe

### Dev Tools (`dev-tools/`)
- `dev-tools` -- git, direnv, git-delta, etc.

### Networking (`networking/`)
- `networking` -- avahi, wireguard-tools, tcpdump, etc.

### Virtualization (`virtualization/`)
- `virtualization/libvirt` -- libvirt, qemu, virt-manager, virt-viewer
- `virtualization/incus` -- incus, lxc, systemd-container
- `virtualization/podman` -- podman-compose, podman-machine, podman-tui
- `virtualization/vfio-passthrough` -- VFIO kargs, modprobe binds, dracut + GPU/USB rebind service (desktop flavor only)
- `virtualization/looking-glass` -- kvmfr DKMS module for GPU passthrough (desktop flavor only)

### Backup (`backup/`)
- `backup/backup-tools` -- borgbackup, rclone, restic

### Hardening (`hardening/`)
- `hardening/hardened-malloc` -- hardened_malloc + no_rlimit_as
- `hardening/sudo-hardening` -- sudoers.d/99-hardening

### Desktop Applications (`apps/`)
- `apps/affinity` -- Affinity Photo/Designer/Publisher via Wine
- `apps/trivalent` -- secureblue's hardened Chromium fork
- `apps/vscodium` -- VSCodium (telemetry-free VS Code), hardened_malloc-exempt wrapped

### VPN (`vpn/`)
- `vpn/mullvad-vpn` -- Mullvad VPN daemon
- `vpn/netbird` -- Netbird mesh VPN
- `vpn/tailscale` -- Tailscale mesh VPN
