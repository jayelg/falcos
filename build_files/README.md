[root](../README.md) / **build_files**

Everything that runs at image build time. These scripts are bind mounted into the build by the [Containerfile](../Containerfile), they are not copied into the final image (apart from the trees under Static Files and the component `files/` overlays).

### [Components](components)

Self-describing, independently cacheable build units, one Containerfile RUN layer each. What gets built is controlled by [COMPONENTS.list](../COMPONENTS.list): edit the list, run `just generate`, commit both. Each layer runs [lib/run-component.sh](lib/run-component.sh), which handles the shared conventions (repo file, version pins, variants, `files/` overlay, justfile recipes).

### [Common Scripts](common)

The build phases around the components: `phase-setup.sh` (pre-install workarounds), `phase-flavor.sh` (flavor overlay + script) and `phase-finalize.sh` (initramfs, presets, final baked tweaks).

### [Flavor Scripts](flavors)

`desktop.sh` and `laptop.sh`: per-flavor branding and notes. Hardware-specific config lives in the matching `files/<flavor>` overlay; flavor-gated components (looking-glass) are handled in COMPONENTS.list.

### [Static Files](files)

Config file trees copied verbatim into the image. `common` applies to every build (copied in phase-finalize), the `desktop` and `laptop` overlays are copied per flavor (phase-flavor). Files owned by a single component live in that component's `files/` directory instead.

### [Shared Libraries](lib)

Shell helpers sourced by the build scripts, not run on their own: the component runner, download/verify helpers, kernel variant resolution, Secure Boot signing, DKMS module builds, hardened_malloc exemption wrappers, SELinux module install and os-release branding.
