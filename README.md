# Falcos

Falcos is a framework for a 'build-your-own distro' using an atomic/immutable linux image that is configured and managed in your own git repo. It provides sensible defaults as a starting point for an out-of-the-box desktop OS that demonstrates how the repo can be used. The objectives of this project are to provide a an easy to configure and maintain linux image where the user has full visibility of what is running on their system without the maintainance burden by providing a providing automations, tools and helper scripts that minimizing abstractions that obscure whats happening under the hood.

## Philosophy

- **Minimal Abstractions**: The repo is a framework for a custom linux image designed to be easy to learn and understand whats happening under the hood while still keeping things organised and easy to maintain.
- **Component Modules**: `components/` Centralizes all build requirements for a feature into a standardized directory structure (This can include a build script with any install or system configuration commands, containerfile commands to include, run time justfile scripts, files to copy, and version pinning with SHA hash).
- **Central Component Management**: `components.list` is the definitive list of all components that are enabled in the built images including common components and components specific to different flavor builds (using a `[Flavor_Name]` tag). a containerfile is generated at build time from the base containerfile that inserts these components before running the containerfile.
- **Flavors**: Image flavors are defined in `Containerfile.base` via `ARG FLAVORS` (valid names) and `ARG FLAVOR` (default). Flavor-specific components are gated by `[flavor]` sections in `components.list`.
- **Secure-Boot & MOK signing for custom kernels**: A script to enrol and use custom kernels with secure-boot enabled.
- **Minimal Base image**: [fedora-bootc](https://quay.io/repository/fedora/fedora-bootc) provides a minimal base image so that the majority of the system configuration is centralized and visible to the user.
- **Kernel freshness automation**: An automation script for custom kernels that will fallback to the stock Fedora kernel if the custom kernel (from COPR) falls behind the upstream stable kernel's security patches.
- **BuildKit Caching**: build layer cache per flavor. Each component caches independently.
- **SBOM**: Syft SPDX scan of the built image.
 - **Chunked OCI**: rpm-ostree repacks into smaller content-stable layers to reduce the download sizes of image changes.
 - **Dependency tracking**: Renovate pins component versions and GitHub Actions hashes.
- **Sensible Defaults**: Configured as a ready to go system. with KDE Plasma DE, Package Managers (Bazaar (Flatpak), Homebrew and Distrobox), Hardening cherry-picked from  [secureblue](https://secureblue.dev/) (hardened_malloc system-wide, the Trivalent browser, and sudo/PAM tightening). These components can be easily disabled (comment out in components.list) or removed as desired.
- **Tools**: `falcos-cli` is TUI tool for system information and running the just scripts. `falcos-bootc-update` provides a tab in System Settings for managing system updates.
- **Automatic Updates**: `bootc-fetch-apply-updates.timer` applies image updates automatically; The image build and flatpaks are updated daily.
- **Image Signing**:Images are cosign-signed and verified against the key baked into the image. 

## How it works

### Components
Anything that you want to include in an image can be packaged into a component. A component is a structured directory that can include scripts, direct file overlays, justfiles, flatpaks, Containerfile segments, and versioning.

Components are then explicity defined for inclusion in the image through the `components.list` file.

### The Containerfile is generated at build time
(`Containerfile.generated`).
During the build `scripts/gen-containerfile.sh` takes `Containerfile.base` and splices in each component as a single RUN layer as they are ordered in the `components.list` file and outputs a `Containerfile.generated` file for use in the build.

### Image Flavors
Flavours refers to image variants that that the build script/Build CI workflow will generate. 

Images flavours are defined by adding a comma delinated list into `Containerfile.base` > `ARG FLAVORS=""`.

Flavors are configured by using the `[<Flavor-Name>]` header tag before a list of components in `components.list`.

The `[Common]` header tag is used for components targeting all built images,

The generated `Containerfile.generated` file is not flavor specific and includes all components listed in the `components.list` file for use in all flavor builds. The build workflow parses the `components.list` file during the build to gate what is installed during each flavor build workflow.

### Image Building
Images are build using the `.github/workflows/build.yml` workflow, signed and published for bootc images to track updates.
The workflow runs daily to rebuild with any updates to the base image and components (that aren't pinned to a version).
Renovate monitors each component's `versions.sh` file and  generates a daily batch update PR with build test checks if any new versions of component dependancies are available.

### Other quality-of-life CI automations

#### Automatically update SHA256 hash for pinned component version bumps 
the `.github/workflows/checksums.yml` workflow runs after approved Renovate version bump PRs to update the components `versions.sh` SHA256 hash properties.

#### Cleanup registry

An optional workflow that runs after the build workflow to prune old image releases.

#### Stale custom kernel fall-back to stock 
This is an optional workflow for security paranoia that ensures the images don't ship with a stale custom kernel that may introduce known exploited vulnerabilites.

When specifying a custom kernel component and enabling the kernel fresheness workflow `.github/workflows/kernel-freshness.yml`, the kernel freshness workflow runs daily. For this to work, the custom kernel component needs to include a `kernel-freshness.py` file.

Eg. For `components/kernel/cachyos-kernel/`, the `kernel-freshness.py` script checks COPR against upstream stable releases and CISA's Known Exploited Vulnerabilities catalog. If the COPR stalls it opens a tracking issue, then a pre-validated PR that temporarily switches the image to the stock Fedora kernel (the `KERNEL` arg in `Containerfile.base`), and a restore PR once the COPR catches up.

#### [Shared libraries](lib)

Shell helpers sourced by the build scripts: component runner, fetch/verify helpers, kernel variant resolution, Secure Boot signing, DKMS module builds, hardened_malloc wrappers, SELinux module install, and os-release branding.

### [Disk config](disk_config)

bootc-image-builder configs for the installer ISO and disk images.

### [Justfile](Justfile)

Dev scripts for building and testing outside CI.

### What to customize

#### [Containerfile.base](Containerfile.base)
Define the base image to use with:
`FROM <base-image>` eg. `FROM quay.io/fedora/fedora-bootc:44`

Define what flavors to build with:
`ARG FLAVORS=""` eg. `ARG FLAVORS="desktop,laptop"`

#### [Components Directory](components)

To add any new app, customization or feature you can make a copy of the  `components/_template/component-name` directory and rename it to a descriptive component name to be used in the `components.list` file. `components/_template/readme.md` explains how to use the component template.

Component directories can also be organised into groups eg. `components/core/brew`. Grouped components must be formatted as `<group-name>/<component-name>` in the components.list eg. `core/brew`.

You can use components in a variety of ways:
- As a single application installation eg. a browser
- A group of related and interdependant applications eg. virtualization
- For any just scripts you want to include ie. justfile.inc
- Layering files trees into the immutable system

#### [components.list](components.list)

This is a list of all components that will be included in the build images.

To include a component from the `components/` directory, you can just add a line with the component name in the order that you would like it to run. If the component is grouped into a directory, it must be formatted as `<group-name>/<component-name>`.

To exclude a component from the build, you can either delete it or comment it out. Component directories in `components/` will not be included unless it is defined in `components.list`.

To include a component for a specific image flavor only, add a `[Flavor-name}` header tag with the flavor name specified in `Containerfile.base` `ARG FLAVORS` list. all components below this flavor header tag will be included only in the specified flavor image. to include component that should be applied to all images after the flavor components have been included, add the `[common]` header tag. This is useful for any scripts that need to run last.

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
   `cp ~/.local/share/falcos/sb_cert.der components/kernel/cachyos-kernel/files/usr/share/falcos/sb_cert.der`
3. Add the private key contents as the `MOK_PRIVATE_KEY` GitHub Actions secret (for local signed builds, `export MOK_KEY_PATH=~/.local/share/falcos/MOK.priv` before `just build`).
4. On each machine, after deploying a signed image:
   `sudo mokutil --import /usr/share/falcos/sb_cert.der`, then reboot and complete the MokManager enrollment prompt.

The private key never enters the repo or the image; CI mounts it as a BuildKit secret and DKMS-generated throwaway keys are scrubbed from the image.

## References

This project was initially built from the [ublue-os/image-template](https://github.com/ublue-os/image-template) which provided the initial structure, build just scripts and github CI workflows.

Some of the default components for hardening and software were cherry-picked from [secureblue](https://secureblue.dev/).
