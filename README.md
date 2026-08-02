# Falcos

Falcos is a framework for a 'build-your-own distro' using an atomic/immutable linux image that is configured and managed in your own git repo. It provides sensible defaults as a starting point for an out-of-the-box desktop OS that demonstrates how the repo can be used. The objectives of this project are to provide a an easy to configure and maintain linux image where the user has full visibility of what is running on their system without the maintainance burden by providing a providing automations, tools and helper scripts that minimizing abstractions that obscure whats happening under the hood.

## Features

- **Minimal Abstractions**: The repo is a framework for custom linux images designed to be easy to learn and understand whats happening under the hood while still keeping things organised and easy to maintain.
- **One file per image**: A repository can declare as many images as it wants, a desktop and a server say, each with its own base, flavors and module list, and each built and published on its own. Adding one is a new file, not an edit to somebody else's list.
- **Module based architecture**: `modules/` Centralizes all build requirements for a feature into a standardized directory structure (This can include a build script with any install or system configuration commands, containerfile commands to include, run time justfile scripts, files to copy, and asset pins with their download URL and SHA256). An image is one `.kdl` file at the repository root, and the image author's file: it names the base image to build on, declares the image's flavors, and defines a definitive list of all modules enabled in it, common ones and ones specific to a flavor. Modules are then spliced into a generated containerfile at build time.
- **System visibility**: The default base image is [fedora-bootc](https://quay.io/repository/fedora/fedora-bootc) which provides a minimal starting point so that the majority of the system configuration is centralized and visible to the user.
- **Security**: A script to enrol and use custom kernels with secure-boot enabled. Hardening modules are included eg. Hardened_Malloc. CI automations include a kernel-freshness workflow that check if a custom kernel is stale and pushes a PR to temporarily swap the kernel to stock to minimize know exploit vulnerabilities in stale kernels. The images are signed with Cosign and Syft SPDX scans the built image against SHA256 hashes.
- **Build Layer Caching and rechunking**: Builtkit is configured to cache all build layers to reduce build timees with each module cached independently. rpm-ostree repacks into smaller content-stable layers to reduce the download sizes of image changes.
- **Dependency tracking**: Renovate pins module versions and GitHub Actions hashes.
- **Update managment tools baked in** `bootc-fetch-apply-updates.timer` applies image updates automatically. The image build and flatpaks are updated daily.`falcos-bootc-update` for KDE Plasma provides a GUI tab in KDE Plasma System Settings for managing system updates. `goojust` provides a TUI tool for system information and running system updates and other included just scripts.

## How it works

### Modules
Anything that you want to include in an image can be packaged into a module. A module is a structured directory that can include scripts, direct file overlays, justfiles, flatpaks, Containerfile segments, and versioning.

Modules are then explicity defined for inclusion in an image through the `modules` block of that image's file.

### One file per image
Every `.kdl` at the repository root is one image, holding what it is called, what it builds on, its flavors and its modules. `repo.kdl` is the one that is not: it holds what is true of the repository, which is which image a bare `just build` builds and which CI workflows run.

The file name decides nothing. Every name the build and the artifact use is declared inside it, so `image.kdl` and `falcos.kdl` are the same image and renaming it changes nothing. This repository ships one image, in [image.kdl](image.kdl); a second would be a second file.

What gets built is a **target**, written `<image>/<flavor>`, with `<image>/none` for the ungated set. `just build` builds the default one; `just build falcos falcos/laptop` names another.

### The build Containerfile is generated
`scripts/gen-containerfile.sh` takes [scripts/Containerfile.skeleton](scripts/Containerfile.skeleton) and splices in the base image `FROM`, one RUN layer per module and one per build phase, writing `containerfiles/<image>.generated`, one per image, which is the file a build of that image uses. [build-phases/](build-phases) is a drop-in directory: a `*.sh` there becomes a layer, ordered by its number around the module layers, which build at 50.

The skeleton lives beside its generator rather than at the repository root, so the only Containerfile you meet here is the one that actually builds. It holds no decisions about the image — the parser directive, the context stage and the pre-publish lint gate — and nothing in it needs editing to change what the image contains.

The generated Containerfiles are committed, so adding a module or reordering the list shows up as the expanded build in the same diff. Every build regenerates them first and lint fails if a committed copy is stale, so they cannot drift from the declarations.

### Image Flavors
Flavors are image variants that the build script and the build CI workflow generate.

Image flavors are declared in the `flavors { }` block inside an image, and modules are gated to one by nesting them in a `flavor "<name>" { }` block. A flavor belongs to the image that declares it, which is why a build target names both.

The ungated set is published too, as `falcos` unsuffixed, and is not declared: it exists because the layers above the flavor gate exist. It is what a fresh installer lays down, because kargs under `/usr/lib/bootc/kargs.d/` are static and cannot be made conditional on hardware. Moving to a device flavor afterwards is a `bootc switch`.

Flavors are optional. Omit the block and the build produces one unnamed image.

An image's generated Containerfile is not flavor specific: it holds every module that image lists, and the `FLAVOR` build arg gates which of them do anything in a given build.

Every layer above the first flavor section is shared by all flavor builds: the flavor is only declared as a build arg at that point, and an arg in scope is part of the cache key of every layer below it. Adding a flavor therefore costs its own gated modules rather than a whole extra build.

### Image Building
Images are build using the `.github/workflows/build.yml` workflow, signed and published for bootc images to track updates.
The workflow runs daily to rebuild with any updates to the base image and modules (that aren't pinned to a version).
Renovate monitors the asset pins in each module's `module.kdl` and generates a daily batch update PR with build test checks if any new versions of module dependancies are available.

### Other quality-of-life CI automations

#### Automatically update SHA256 hash for pinned module version bumps 
the `.github/workflows/checksums.yml` workflow runs after approved Renovate version bump PRs to update the `sha256` of every asset pin whose version moved, and to regenerate the Containerfile the pins are baked into.

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

#### [image.kdl](image.kdl), this repository's one image

Name the image, and point at the assets it wears. The machine name it
publishes under is derived from `name` lowercased, so `Falcos` publishes as
`falcos`; declare `id` when the two should differ:

```kdl
image {
    name "Falcos"
    url "https://github.com/jayelg/falcos"
    issues-url "https://github.com/jayelg/falcos/issues"
    logo "brand/distributor-logo-symbolic.svg"
    watermark "brand/watermark.png"
}
```

This is the only place the brand is written down. os-release carries it,
so the same declaration is what the boot menu, the desktop's about page
and the default hostname read, and it is what the published image is
called (`falcos`, `falcos-desktop`). Assets live in [brand/](brand) and
are installed by the flavor phase. No module names the image: one that
needs it reads `/etc/os-release` on the running system.

Where the image publishes is not declared: `scripts/registry.sh` derives
that from the git remote, so a fork's images, cache and signature policy
follow the fork with no edit.

Inside the same `image` block, define the base image to build on, the
family the modules may assume, and what the base brings with it:

```kdl
base "quay.io/fedora/fedora-bootc:44" {
    family "fedora"
    provides "rechunking" "initramfs-generation" "mac-policy"
    provides-file "/usr/bin/bootc" "/usr/bin/systemctl" "/usr/bin/rpm-ostree"
}
```

This is the only place this image's base is named; the `FROM` in its
generated Containerfile is emitted from it. Another image declares its own,
and need not build on the same thing.

Define what flavors of it to build, in the same block:

```kdl
flavors {
    desktop default=#true pr-build=#true
    laptop
}
```

`default` is the flavor `just build` produces when given none; `pr-build` is the single flavor a pull request builds. They are marked rather than inferred from position, because three unrelated policies had accumulated on "first entry" and collided.

This is the only place this image's flavors are declared. Everything downstream derives from it: the build matrix, the published image names (`falcos-<flavor>`), the per-target build cache tags, the registry cleanup and the local `just build` default. Adding a flavor needs no other edit.

That script also declares which flavor a fresh installer lays down, the one flavor choice that is a policy rather than a derivation.

#### [repo.kdl](repo.kdl)

What is true of the repository rather than of any image in it, and the one
root `.kdl` that is not an image. It ships holding nothing but comments,
because a repository with one image and no opinion about its workflows
needs none of it:

```kdl
default-image "falcos"

workflows {
    smoke-test enabled=#false
}
```

`default-image` says which image `just build` builds, and is required as
soon as a second image is declared. The `workflows` block switches a
pipeline in [.github/workflows/](.github/workflows) off by file stem, for a
fork that wants the weekly smoke test quiet or has no registry to publish
to; it is reconciled through the GitHub API rather than by rewriting the
files. Nothing here reaches a build.

#### [Modules Directory](modules)

To add any new app, customization or feature you can make a copy of the  `modules/_template/module-name` directory and rename it to a descriptive module name to be listed by an image. `modules/_template/readme.md` explains how to use the module template.

Module directories can also be organised into groups eg. `modules/core/brew`. Grouped modules must be formatted as `<group-name>/<module-name>` in the module list eg. `core/brew`.

You can use modules in a variety of ways:
- As a single application installation eg. a browser
- A group of related and interdependant applications eg. virtualization
- For any just scripts you want to include ie. justfile.inc
- Layering files trees into the immutable system

#### [The module list](image.kdl)

This is a list of all modules that will be included in the build images.

To include a module from the `modules/` directory, you can just add a line with the module name. If the module is grouped into a directory, it must be formatted as `<group-name>/<module-name>`.

The build order is resolved from what the modules declare: one that `requires` a capability builds after whatever provides it, and ungated modules build before flavor-gated ones. This list is the tie-break for everything the graph says nothing about, so it is still where "less frequently updated first, for layer caching" is expressed. The resolved order is visible in the committed Containerfile.

To exclude a module from the build, you can either delete it or comment it out. Module directories in `modules/` will not be included unless the image lists them.

A module kept in another repository is included the same way, with a `source` block on its entry pinning the archive, the ref and its SHA256. It is fetched and verified on the host before the build and then builds as any other module does, so the only difference in the image is which repository the layer came from. See [out-of-tree modules](modules/README.md#out-of-tree-modules).

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
just build              # build the default target (the default image, at its default flavor)
just build-qcow2        # convert it to a bootable qcow2 via bootc-image-builder
just run-vm-qcow2       # boot it in a browser-accessible VM
just lint               # shellcheck every Bash script and validate every manifest, the same script CI gates on
```

`just build` and the build workflow both run [scripts/build.sh](scripts/build.sh), so a local build gets the same Containerfile, build args, cache refs and signing secret as CI.

Local builds use BuildKit, running as a `podman` container (`moby/buildkit`) driven by `buildctl`, and the built image is loaded into podman storage as `localhost/falcos:latest`. This is the same builder CI uses, so each `RUN` layer is invalidated by the files that layer mounts rather than by any change to the build context: editing one module rebuilds one layer. BuildKit's state, which is both the layer cache and every `RUN --mount=type=cache`, lives in the `falcos-buildkit` podman volume; `just buildkit-reset` deletes it and the daemon container. `just build-buildah` builds with buildah instead, for a host where the BuildKit container cannot run.

Because it is the same builder, a local build also reads the registry layer cache that CI writes (`falcos-cache`, one tag per flavor, read anonymously). A build of a commit CI has already built is then a full cache hit, minutes rather than the ~50 a cold build takes, and a working tree that differs from it only rebuilds the layers that actually changed. What it can hit depends on the build context matching a clean checkout, which is what [.dockerignore](.dockerignore) is for: a stray `__pycache__` under `modules/` changes the layer every module build mounts from and costs the entire cache. `IMAGE_REGISTRY` overrides where the cache is read from; it otherwise follows the `origin` remote, so a fork reads its own.

## Secure Boot

The image supports Secure Boot via a self-managed MOK (Machine Owner Key). When a signing key is supplied at build time, the CachyOS kernel and every kernel module — including the out-of-tree DKMS modules (xone, kvmfr) — are signed with it. Without the key the build still succeeds but kernel and modules are unsigned (fine for VMs and machines with Secure Boot disabled). The stock Fedora fallback kernel is already signed by Fedora's key, which shim trusts; the MOK then only matters for the out-of-tree modules.

One-time setup:

1. `just generate-mok-key` — creates the key pair under `~/.local/share/falcos/`.
2. Copy the public cert into the repo and commit it:
   `cp ~/.local/share/falcos/sb_cert.der modules/kernel/cachyos-kernel/files/usr/share/secureboot/sb_cert.der`
3. Add the private key contents as the `MOK_PRIVKEY` GitHub Actions secret. The module manifests declare the secret as `mok_privkey`, which the build workflow satisfies from its `SECRET_MOK_PRIVKEY` env line; a module asks for a secret by ID and the workflow decides whether to hand one over. For local signed builds, `export MOK_KEY_PATH=~/.local/share/falcos/MOK.priv` before `just build`.
4. On each machine, after deploying a signed image:
   `sudo mokutil --import /usr/share/secureboot/sb_cert.der`, then reboot and complete the MokManager enrollment prompt.

The private key never enters the repo or the image; CI mounts it as a BuildKit secret and DKMS-generated throwaway keys are scrubbed from the image.

Rotating the key. A MOK is a list, so enrolling the new cert before anything is signed with it leaves no machine unbootable:

1. `just generate-mok-key`, which refuses to overwrite an existing key.
2. Copy the new `sb_cert.der` to each machine by hand and enroll it there while that machine still runs the old image: `sudo mokutil --import sb_cert.der`, reboot, complete MokManager. The old key stays enrolled, so the running image keeps booting. Step 4 of the setup above reads the cert out of the image, which carries the new one only after the update has landed, so it is the wrong order for a rotation.
3. Commit the new cert, and set `MOK_PRIVKEY` to the new private key.
4. Build and publish. Machines update and boot on the new key.
5. Once every machine is on it, `sudo mokutil --delete` the old cert.

The wrong key never blocks an update. `bootc upgrade` verifies the image with cosign, which is independent of the MOK, so an image signed by an unenrolled key (or by no key, when `MOK_PRIVKEY` is missing and the build logs a warning) stages normally and then fails to boot on Secure Boot machines only. Recovery is selecting the previous deployment in GRUB, at the console, since MokManager cannot be driven over SSH.

## References

This project was initially built from the [ublue-os/image-template](https://github.com/ublue-os/image-template) which provided the initial structure, build just scripts and github CI workflows.

Some of the default modules for hardening and software were cherry-picked from [secureblue](https://secureblue.dev/).
