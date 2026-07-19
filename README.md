# Falcos

Falcos is a self-managed atomic desktop Linux image. It is based on a minimal fedora-bootc image so that the majority of software and configuration is managed in this repo. It uses GitHub Actions and Renovate to automate image updates when upstream updates become available.

## Features

- **Base image**: [fedora-bootc](https://quay.io/repository/fedora/fedora-bootc)
- **Kernel**: [CachyOS kernel](https://copr.fedorainfracloud.org/coprs/bieszczaders/kernel-cachyos/), with an automated fallback to the stock Fedora kernel when the COPR falls behind upstream stable (see [Kernel freshness](#kernel-freshness))
- **Desktop**: KDE Plasma
- **Package managers**: Flatpak, Homebrew
- **Hardening**: cherry-picked from [secureblue](https://secureblue.dev/) — hardened_malloc system-wide, the Trivalent browser, sudo/PAM tightening
- **Updates**: `bootc-fetch-apply-updates.timer` applies image updates automatically; Flatpaks update daily; images are cosign-signed and verified against the key baked into the image

## Build flavours

Two personal variants, published as separate images:

- `ghcr.io/jayelg/falcos-desktop` — tweaks for my desktop hardware (VFIO GPU passthrough, Looking Glass)
- `ghcr.io/jayelg/falcos-laptop` — tweaks for my Framework 13 laptop

## Installation

### Rebase an existing bootc / atomic system

```bash
sudo bootc switch ghcr.io/jayelg/falcos-laptop:latest   # or falcos-desktop
```

### Fresh install

The [Build disk images](.github/workflows/build-disk.yml) workflow produces an Anaconda installer ISO and a qcow2 disk image (run it via workflow dispatch and download the artifacts). The ISO installs the laptop flavor and switches itself to track `ghcr.io/jayelg/falcos-laptop:latest`.

### Local builds

```bash
just build              # build the container image (FLAVOR=laptop by default)
just build-qcow2        # convert it to a bootable qcow2 via bootc-image-builder
just run-vm-qcow2       # boot it in a browser-accessible VM
just lint               # shellcheck, same file set as CI
```

## Secure Boot

The image supports Secure Boot via a self-managed MOK (Machine Owner Key). When a signing key is supplied at build time, the CachyOS kernel and every kernel module — including the out-of-tree DKMS modules (xone, kvmfr) — are signed with it. Without the key the build still succeeds but kernel and modules are unsigned (fine for VMs and machines with Secure Boot disabled). The stock Fedora fallback kernel is already signed by Fedora's key, which shim trusts; the MOK then only matters for the out-of-tree modules.

One-time setup:

1. `just generate-mok-key` — creates the key pair under `~/.local/share/falcos/`.
2. Copy the public cert into the repo and commit it:
   `cp ~/.local/share/falcos/sb_cert.der build_files/files/common/usr/share/falcos/sb_cert.der`
3. Add the private key contents as the `MOK_PRIVATE_KEY` GitHub Actions secret (for local signed builds, `export MOK_KEY_PATH=~/.local/share/falcos/MOK.priv` before `just build`).
4. On each machine, after deploying a signed image:
   `sudo mokutil --import /usr/share/falcos/sb_cert.der`, then reboot and complete the MokManager enrollment prompt.

The private key never enters the repo or the image; CI mounts it as a BuildKit secret and DKMS-generated throwaway keys are scrubbed from the image.

## Repo structure

### [COMPONENTS.list](COMPONENTS.list)

The source of truth for what goes in the image: one component per line, in build order. Editing the list is all that's needed — both `just build` and the CI build generate the real build file (`Containerfile.generated`, untracked) from it before building.

### [Containerfile](Containerfile)

The build skeleton: the base image, the setup phase, an empty marker section where one RUN layer per COMPONENTS.list entry is spliced in at build time (so each component caches independently and frequent updates never cause a full rebuild), the flavor and finalize phases, and `bootc container lint` on the final image.

### [Build files](build_files)

Everything that runs at build time: the components, the phase scripts, the shared helper libraries and the static file trees copied into the image.

### [GitHub Actions](.github/workflows)

CI workflows that build, sign and publish the images, lint and test the repo, prune the registry, and keep dependencies fresh via Renovate.

#### Kernel freshness

The kernel freshness workflow watches the CachyOS kernel COPR against upstream stable releases and CISA's Known Exploited Vulnerabilities catalog. If the COPR stalls it opens a tracking issue, then a pre-validated PR that temporarily switches the image to the stock Fedora kernel (the `KERNEL` arg in the Containerfile), and a restore PR once the COPR catches up.

### [Disk config](disk_config)

bootc-image-builder configs for the installer ISO and disk images.

### [Justfile](Justfile)

Dev scripts for building and testing outside CI.

## References

Based on [ublue-os/image-template](https://github.com/ublue-os/image-template), following a similar implementation to Universal Blue's Aurora and Bazzite images, with hardening and software from [secureblue](https://secureblue.dev/).
