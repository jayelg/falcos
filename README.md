# Falcos

Falcos is a framework for a 'build-your-own distro' using an atomic/immutable linux image that is configured and managed in your own git repo. It provides sensible defaults as a starting point for an out-of-the-box desktop OS that demonstrates how the repo can be used. The objectives of this project are to provide a an easy to configure and maintain linux image where the user has full visibility of what is running on their system without the maintainance burden by providing a providing automations, tools and helper scripts that minimizing abstractions that obscure whats happening under the hood.

## Features

- **Minimal Abstractions**: The repo is a framework for a custom linux image designed to be easy to learn and understand whats happening under the hood while still keeping things organised and easy to maintain.
- **Module based architecture**: `modules/` Centralizes all build requirements for a feature into a standardized directory structure (This can include a build script with any install or system configuration commands, containerfile commands to include, run time justfile scripts, files to copy, and version pinning with SHA hash). `modules.kdl` then defines a definitive list of all modules that are enabled in the built images including common modules and modules specific to different flavor builds (using a `[Flavor_Name]` tags). Modules are then spliced into a generated containerfile at build time.
- **System visibility**: The default base image is [fedora-bootc](https://quay.io/repository/fedora/fedora-bootc) which provides a minimal starting point so that the majority of the system configuration is centralized and visible to the user.
- **Security**: A script to enrol and use custom kernels with secure-boot enabled. Hardening modules are included eg. Hardened_Malloc. CI automations include a kernel-freshness workflow that check if a custom kernel is stale and pushes a PR to temporarily swap the kernel to stock to minimize know exploit vulnerabilities in stale kernels. The images are signed with Cosign and Syft SPDX scans the built image against SHA256 hashes.
- **Build Layer Caching and rechunking**: Builtkit is configured to cache all build layers to reduce build timees with each module cached independently. rpm-ostree repacks into smaller content-stable layers to reduce the download sizes of image changes.
- **Dependency tracking**: Renovate pins module versions and GitHub Actions hashes.
- **Update managment tools baked in** `bootc-fetch-apply-updates.timer` applies image updates automatically. The image build and flatpaks are updated daily.`falcos-bootc-update` for KDE Plasma provides a GUI tab in KDE Plasma System Settings for managing system updates. `goojust` provides a TUI tool for system information and running system updates and other included just scripts.

## How it works

### Modules
Anything that you want to include in an image can be packaged into a module. A module is a structured directory that can include scripts, direct file overlays, justfiles, flatpaks, Containerfile segments, and versioning.

Modules are then explicity defined for inclusion in the image through the `modules.kdl` file.

### The build Containerfile is generated
`scripts/gen-containerfile.sh` takes `Containerfile.template` and splices in one RUN layer per module and one per build phase, writing `Containerfile.generated`, which is the file builds use. [build-phases/](build-phases) is a drop-in directory: a `*.sh` there becomes a layer, ordered by its number around the module layers, which build at 50.

`Containerfile.generated` is committed, so adding a module or reordering the list shows up as the expanded build in the same diff. Every build regenerates it first and lint fails if the committed copy is stale, so it cannot drift from `modules.kdl`.

### Image Flavors
Flavours refers to image variants that that the build script/Build CI workflow will generate. 

Image flavours are declared in the `flavors { }` block at the top of `modules.kdl`, and modules are gated to one by nesting them in a `flavor "<name>" { }` block.

The ungated set is published too, as `falcos` unsuffixed, and is not declared: it exists because the layers above the flavor gate exist. It is what a fresh installer lays down, because kargs under `/usr/lib/bootc/kargs.d/` are static and cannot be made conditional on hardware. Moving to a device flavor afterwards is a `bootc switch`.

Flavors are optional. Omit the block and the build produces one unnamed image.

The `[Common]` header tag is used for modules targeting all built images,

The generated `Containerfile.generated` file is not flavor specific and includes all modules listed in the `modules.kdl` file for use in all flavor builds. The build workflow parses the `modules.kdl` file during the build to gate what is installed during each flavor build workflow.

Every layer above the first flavor section is shared by all flavor builds: the flavor is only declared as a build arg at that point, and an arg in scope is part of the cache key of every layer below it. Adding a flavor therefore costs its own gated modules rather than a whole extra build.

### Image Building
Images are build using the `.github/workflows/build.yml` workflow, signed and published for bootc images to track updates.
The workflow runs daily to rebuild with any updates to the base image and modules (that aren't pinned to a version).
Renovate monitors each module's `versions.sh` file and  generates a daily batch update PR with build test checks if any new versions of module dependancies are available.

### Other quality-of-life CI automations

#### Automatically update SHA256 hash for pinned module version bumps 
the `.github/workflows/checksums.yml` workflow runs after approved Renovate version bump PRs to update the modules `versions.sh` SHA256 hash properties.

#### Cleanup registry

An optional workflow that runs after the build workflow to prune old image releases.

#### Stale custom kernel fall-back to stock 
This is an optional workflow for security paranoia that ensures the images don't ship with a stale custom kernel that may introduce known exploited vulnerabilites.

When specifying a custom kernel module and enabling the kernel fresheness workflow `.github/workflows/kernel-freshness.yml`, the kernel freshness workflow runs daily. For this to work, the custom kernel module needs to include a `kernel_freshness.py` file.

Eg. For `modules/kernel/cachyos-kernel/`, the `kernel_freshness.py` script checks COPR against upstream stable releases and CISA's Known Exploited Vulnerabilities catalog. If the COPR stalls it opens a tracking issue, then a pre-validated PR that temporarily switches the image to the stock Fedora kernel (the `KERNEL` arg in the module's Containerfile fragment), and a restore PR once the COPR catches up.

#### [Shared libraries](lib)

Shell helpers sourced by the build scripts: module runner, fetch/verify helpers, kernel variant resolution, Secure Boot signing, DKMS module builds, hardened_malloc wrappers, SELinux module install, and os-release branding.

### [Disk config](disk_config)

bootc-image-builder configs for the installer ISO and disk images.

### [Justfile](Justfile)

Dev scripts for building and testing outside CI.

### What to customize

#### [Containerfile.template](Containerfile.template)
Define the base image to use with:
`FROM <base-image>` eg. `FROM quay.io/fedora/fedora-bootc:44`

Define what flavors to build in `modules.kdl`:

```kdl
flavors {
    desktop default=#true pr-build=#true
    laptop
}
```

`default` is the flavor `just build` produces when given none; `pr-build` is the single flavor a pull request builds. They are marked rather than inferred from position, because three unrelated policies had accumulated on "first entry" and collided.

This is the only place flavors are declared. Everything downstream derives from it: the build matrix, the published image names (`falcos-<flavor>`), the per-target build cache tags, the registry cleanup and the local `just build` default. Adding a flavor needs no other edit.

That script also declares which flavor a fresh installer lays down, the one flavor choice that is a policy rather than a derivation.

#### [Modules Directory](modules)

To add any new app, customization or feature you can make a copy of the  `modules/_template/module-name` directory and rename it to a descriptive module name to be used in the `modules.kdl` file. `modules/_template/readme.md` explains how to use the module template.

Module directories can also be organised into groups eg. `modules/core/brew`. Grouped modules must be formatted as `<group-name>/<module-name>` in the modules.kdl eg. `core/brew`.

You can use modules in a variety of ways:
- As a single application installation eg. a browser
- A group of related and interdependant applications eg. virtualization
- For any just scripts you want to include ie. justfile.inc
- Layering files trees into the immutable system

#### [modules.kdl](modules.kdl)

This is a list of all modules that will be included in the build images.

To include a module from the `modules/` directory, you can just add a line with the module name. If the module is grouped into a directory, it must be formatted as `<group-name>/<module-name>`.

The build order is resolved from what the modules declare: one that `requires` a capability builds after whatever provides it, and ungated modules build before flavor-gated ones. This list is the tie-break for everything the graph says nothing about, so it is still where "less frequently updated first, for layer caching" is expressed. The resolved order is visible in the committed `Containerfile.generated`.

To exclude a module from the build, you can either delete it or comment it out. Module directories in `modules/` will not be included unless it is defined in `modules.kdl`.

To include a module in one flavor only, nest it in a `flavor "<name>" { }` block naming a declared flavor. Modules outside any such block are ungated and build once, shared by every flavor, wherever they are listed: an ungated module always sorts above the gated ones, so a line after a flavor block no longer costs a layer per target.

## Installation

### Rebase an existing bootc / atomic system

Clone this repo to your own github account

```bash
sudo bootc switch ghcr.io/[your username]/falcos-desktop:latest
```

Or `falcos` unsuffixed for the ungated image, which carries no hardware-specific kargs.

### Fresh install

The [Build disk images](.github/workflows/build-disk.yml) workflow produces an Anaconda installer ISO and a qcow2 disk image (run it via workflow dispatch and download the artifacts). The ISO installs the ungated `falcos` image and switches the installed system to track it, ie. `ghcr.io/[your username]/falcos:latest`.

It lays down the ungated image by rule, not by a configured value. Kargs under `/usr/lib/bootc/kargs.d/` are static and cannot be made conditional on hardware, so anything a flavor gates is a claim about a machine the installer has not seen: the desktop flavor's VFIO kargs would bind devices to `vfio-pci` at boot on unknown hardware.

Once installed and booted, move to the flavor that matches the machine:

```bash
sudo bootc switch ghcr.io/[your username]/falcos-desktop:latest
```

Images are rechunked, so that downloads the difference (kargs, device tweaks, a DKMS module) rather than a second full image.

The namespace comes from your `origin` remote, so a fork's ISO installs the fork's own image with no edit. `just build-iso` renders the same reference locally.

### Local builds

```bash
just build              # build the container image (the flavor marked default in modules.kdl)
just build-qcow2        # convert it to a bootable qcow2 via bootc-image-builder
just run-vm-qcow2       # boot it in a browser-accessible VM
just lint               # shellcheck every Bash script and validate modules.kdl, the same script CI gates on
```

`just build` and the build workflow both run [scripts/build.sh](scripts/build.sh), so a local build gets the same Containerfile, build args, cache refs and signing secret as CI.

Local builds use BuildKit, running as a `podman` container (`moby/buildkit`) driven by `buildctl`, and the built image is loaded into podman storage as `localhost/falcos:latest`. This is the same builder CI uses, so each `RUN` layer is invalidated by the files that layer mounts rather than by any change to the build context: editing one module rebuilds one layer. BuildKit's state, which is both the layer cache and every `RUN --mount=type=cache`, lives in the `falcos-buildkit` podman volume; `just buildkit-reset` deletes it and the daemon container. `just build-buildah` builds with buildah instead, for a host where the BuildKit container cannot run.

Because it is the same builder, a local build also reads the registry layer cache that CI writes (`falcos-cache`, one tag per flavor, read anonymously). A build of a commit CI has already built is then a full cache hit, minutes rather than the ~50 a cold build takes, and a working tree that differs from it only rebuilds the layers that actually changed. What it can hit depends on the build context matching a clean checkout, which is what [.dockerignore](.dockerignore) is for: a stray `__pycache__` under `modules/` changes the layer every module build mounts from and costs the entire cache. `IMAGE_REGISTRY` overrides where the cache is read from; it otherwise follows the `origin` remote, so a fork reads its own.

## Secure Boot

The image supports Secure Boot via a self-managed MOK (Machine Owner Key). When a signing key is supplied at build time, the CachyOS kernel and every kernel module — including the out-of-tree DKMS modules (xone, kvmfr) — are signed with it. Without the key the build still succeeds but kernel and modules are unsigned (fine for VMs and machines with Secure Boot disabled). The stock Fedora fallback kernel is already signed by Fedora's key, which shim trusts; the MOK then only matters for the out-of-tree modules.

One-time setup:

1. `just generate-mok-key` — creates the key pair under `~/.local/share/falcos/`.
2. Copy the public cert into the repo and commit it:
   `cp ~/.local/share/falcos/sb_cert.der modules/kernel/cachyos-kernel/files/usr/share/falcos/sb_cert.der`
3. Add the private key contents as the `MOK_PRIVATE_KEY` GitHub Actions secret (for local signed builds, `export MOK_KEY_PATH=~/.local/share/falcos/MOK.priv` before `just build`).
4. On each machine, after deploying a signed image:
   `sudo mokutil --import /usr/share/falcos/sb_cert.der`, then reboot and complete the MokManager enrollment prompt.

The private key never enters the repo or the image; CI mounts it as a BuildKit secret and DKMS-generated throwaway keys are scrubbed from the image.

## References

This project was initially built from the [ublue-os/image-template](https://github.com/ublue-os/image-template) which provided the initial structure, build just scripts and github CI workflows.

Some of the default modules for hardening and software were cherry-picked from [secureblue](https://secureblue.dev/).
