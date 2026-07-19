# Falcos

Falcos is a self-managed atomic Linux image repo based on a minimal fedora-bootc image. The objectives of this project is to provide a low maintainance 'build your own distro' framework image that users can clone and customize. The minimal base image (Fedora-bootc) ensures the majority of the system's software and configurations live in one place managed by the user rather than in an upstream image allowing for extensive control and visibility. Quality of life tools to manage updates from the running system and github CI automations ensure the system and software stays patched and up to date without excessive active management.  

## Features

- **Minimal Abstractions**: The repo is a custom linux image framework designed to be easy to learn and understand how it works while still keeping things organised and easy to maintain.
- **Component Modules**: `build_files/components` Centralizes all build requirements for a feature into a standardized directory structure (This can include a build script with any install or system configuraiton commands, containerfile commands to include, run time justfile scripts, files to copy, and version pinning with SHA hash).
- **Central Component Management**: `COMPONENTS.list` is the definitive list of all components that are enabled in the built images including common components and components specific to different flavor builds (using a `[Flavor_Name]` tag). a containerfile is generated at build time from the base containerfile that inserts these components before running the containerfile.
- **Flavors**: `FLAVORS.list` is the centralized location to define the different builds you want it to generate eg. specific builds for different systems.
- **Secure-Boot & MOK signing for custom kernels**: A script to enrol and use custom kernels with secure-boot enabled. 
- **Minimal Base image**: [fedora-bootc](https://quay.io/repository/fedora/fedora-bootc) provides a minimal base image so that the majority of the system configuration is centralized and visible to the user.
- **Kernel freshness automation**: An automation script for custom kernels that will fallback to the stock Fedora kernel if the custom kernel (from COPR) falls behind the upstream stable kernel's security patches.
- **BuildKit Caching**: build layer cache per flavor. Each component caches independently.
- **SBOM**: Syft SPDX scan of the built image.
 - **Chunked OCI**: rpm-ostree repacks into smaller content-stable layers to reduce the download sizes of image changes.
 - **Dependency tracking**: Renovate pins component versions and GitHub Actions hashes.
- **Sensible Defaults**: Configured as a ready to go system. with KDE Plasma DE, Package Managers (Bazaar (Flatpak), Homebrew and Distrobox), Hardening cherry-picked from  [secureblue](https://secureblue.dev/) (hardened_malloc system-wide, the Trivalent browser, and sudo/PAM tightening). These components can be easily disabled (comment out in COMPONENTS.list) or removed as desired.
- **Tools**: `falcos-cli` is TUI tool for system information and running the just scripts. `falcos-bootc-update` provides a tab in System Settings for managing system updates.
- **Automatic Updates**: `bootc-fetch-apply-updates.timer` applies image updates automatically; The image build and flatpaks are updated daily.
- **Image Signing**:Images are cosign-signed and verified against the key baked into the image. 

## Installation

### Rebase an existing bootc / atomic system

Clone this repo to your own github account

```bash
sudo bootc switch ghcr.io/[your username]/falcos-desktop:latest
```

### Fresh install

The [Build disk images](.github/workflows/build-disk.yml) workflow produces an Anaconda installer ISO and a qcow2 disk image (run it via workflow dispatch and download the artifacts). The ISO installs the laptop flavor and switches itself to track your repo ie. `ghcr.io/[your username]/falcos-desktop:latest`.

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

### [FLAVORS.list](FLAVORS.list)

In here you can define different build 'flavors' which can be used to create 'dev' versions, or create device specific builds with the required hardware drivers, configurations and apps.

The flavor name will define the system host name by default, however a custom hostname for the image can also be defined here.

### [Containerfile](Containerfile)

This is the skeleten used for generating the build containerfile. It includes the base image definition, the setup phase script, an empty marker section where one RUN layer per COMPONENTS.list entry is spliced in at build time (each component will then cache independently reducing the build time for changes), then the flavor and finalize phases, then a `bootc container lint` on the final image.

### [Build files](build_files)

This directory contains all of the files that can run at build time including the components, the phase scripts, the shared helper libraries and static file trees copied into the image.

### [GitHub Actions](.github/workflows)

CI workflows that build, sign and publish the images, lint and test the repo, prune the registry, and keep dependencies fresh via Renovate.

#### Kernel freshness

The kernel freshness workflow watches the CachyOS kernel COPR against upstream stable releases and CISA's Known Exploited Vulnerabilities catalog. If the COPR stalls it opens a tracking issue, then a pre-validated PR that temporarily switches the image to the stock Fedora kernel (the `KERNEL` arg in the Containerfile), and a restore PR once the COPR catches up.

### [Disk config](disk_config)

bootc-image-builder configs for the installer ISO and disk images.

### [Justfile](Justfile)

Dev scripts for building and testing outside CI.

## References

This project was initially built from the [ublue-os/image-template](https://github.com/ublue-os/image-template) which provided the initial structure (build_files directory), build just scripts and github CI workflows.

Some of the default components for hardening and software were cherry-picked from [secureblue](https://secureblue.dev/).
