[root](../README.md) / [build-phases](../build-phases/README.md) / **modules**

A Module can represent a feature or collection of related features which can be defined in multiple ways eg. an app install, a kernel swap, or just a directory drop. Each module included in an image becomes its own Containerfile RUN layer.

To be included in image builds, the module must be defined in the modules node in image files eg. [image.kdl](../image.kdl).

# Assets in the module directory

## Repo supported assets
### module.kdl (required)
Every module must have a `module.kdl` file as a manifest that can declare a variety of properties about a module including:
- What Linux family it supports
- What it requires
- What it provides
- What files it collects from other modules eg. the Flatpak module declares it collects flatpak.list files

The [../SCHEMA.md](../SCHEMA.md) file provides the full list of supported properties.
### module.sh (optional)
  A shell script that will run during the modules RUN step in the image build.
#### repo (optional)
package repo setup, all image repos required for the module are collected and added to the image just after the the base image. Repos are idempotent.
### selinux/*.te (optional)
local SELinux policy modules can be provided for the module packages. Each policy is auto-compiled and installed at priority 200 
### files/ (optional)
A directory and file structure copied verbatim into the image
### finalize.sh (optional)
A script that will run once all other modules are installed and the real systemctl is ready in the final stage of the build eg. service masking, policy.json edits.
### Containerfile.inc (optional)
A verbatim Containerfile lines added above the generated module block. This is useful for what can't express within scripts e.g. defining an ARG.

## Module supported assets
These files will be collected only if the supporting module is included in the image definition.
### justfile.inc (optional)
just recipes, collected at build time by a just runner module eg. the Goojust module.
### flatpak.inc
a list of flatpak packages collected at build time by the flatpak module.

## Defining modules in the image kdl file

A module must be defined in the image > modules section of the image kdl file. The module name follows the directory name of the module. Modules that are organized into group subdirectories (e.g. `core/`, `dev-tools/`, `hardware/`) must include the path relative to the modules directory e.g. `core/auto-updates` for `modules/core/auto-updates/`.

## Template Module

To help create a new module the [`_template/module-name/`](_template/module-name) can be copied which contains an example of different capabilities eg. (manifest, helpers, preset, finalize.sh, options, Containerfile.inc, SELinux). A walkthrough README in [`_template/`](_template) provides some further guidance.

### Out-of-tree modules

A module does not have to live here. An entry in [image.kdl](../image.kdl) carrying a `source` block pins a module from another repository by URL, ref and SHA256. it is fetched and verified on the host before the build, into a gitignored `modules/.remote/<name>/`. The generator emits the same layer it would for a module in this tree. The pin format is in [SCHEMA.md](../SCHEMA.md#out-of-tree-modules).

### Publishing modules

For a repository that publishes modules for others to pin:

- **One git tag per module**, `<module-name>/vX.Y.Z`, the Go multi module convention. A bump to one module leaves every other consumer's pin untouched, and Renovate watches a single tag prefix through `extractVersion`.
- **Not version directories** (`modules/<name>/v1/`, `v2/`). They duplicate code, make a bugfix ambiguous across versions, grow without bound and restate what git history already holds. Simultaneous versions are all they buy, and an image installs a module once.
- Tags are a convenience for humans and Renovate, not a correctness requirement. The pin already carries a ref and a content hash, so an untagged commit is exactly as precise.
- A module needs no version field of its own, and must not grow one. The version lives at the consumption site, as the pin, and in the publishing repository's tags.
- Prefer a release asset attached to the tag over a forge generated `/archive/` tarball where a repository publishes one. A generated archive is not guaranteed byte stable, and a forge that regenerates one fails every consumer's fetch until each recomputes the hash.
- OCI artifacts per module are the upgrade path if module distribution becomes a product: version is a tag, integrity is a digest, signing is cosign, all of which this stack already runs.

# Module descriptions

### Desktop Environment (`de/`)
- `de/kde-desktop` -- KDE Plasma Desktop group install, apps, krunner-bazaar
- `de/kde-theming` -- Darkly, Ant, AWW, papirus icons
- `de/plasma-bootc-updates` -- bootc updates panel for KDE System Settings + notifier (installs after kde-desktop)
- `de/plasma-network-audio` -- Plasma network/audio settings module

### Core System (`core/`) -- do not disable
- `core/bootloader` -- GRUB os-prober for dual boot + the `regenerate-grub` recipe
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
- `hardening/coredumps` -- coredumps off, in systemd and through PAM limits
- `hardening/login-policy` -- sshd off, faillock lockout, password quality, rescue sulogin
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
