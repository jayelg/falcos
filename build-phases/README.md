[root](../README.md) / **build-phases**

Everything that runs at image build time. These scripts are bind mounted into the build by the [Containerfile.template](../Containerfile.template), they are not copied into the final image (apart from the module `files/` overlays).

### [Modules](../modules)

Self-describing, independently cacheable build units, one Containerfile RUN layer each. What gets built is controlled by [modules.kdl](../modules.kdl): edit the list, run `just generate`, commit both. Each layer runs [lib/run-module.sh](../lib/run-module.sh), which handles the shared conventions (repo file, version pins, variants, `files/` overlay, justfile recipes).

### Phase Scripts

The build phases around the modules, numbered to show their order relative to the module RUN layers that sit between them:

- [00-setup.sh](00-setup.sh) -- pre-install workarounds (systemctl stub, `/opt` shuffle) and `dnf5-plugins` for the module repo files. First RUN layer.
- [50-flavor.sh](50-flavor.sh) -- applies os-release branding (NAME, PRETTY_NAME, DEFAULT_HOSTNAME) via [lib/brand-helpers.sh](../lib/brand-helpers.sh). Runs after all modules; the desktop/laptop layer cache forks here. Flavor-specific files ship in flavor-gated modules (e.g. `virtualization/vfio-passthrough`, `hardware/laptop-tweaks`).
- [99-finalize.sh](99-finalize.sh) -- restores systemctl, regenerates the initramfs, relocates `/opt` payloads, applies the falcos systemd presets, runs per-module `finalize.sh` hooks, and the remaining global tweaks (GRUB os-prober, composefs SELinux workaround). Last RUN layer.

### Service enablement

Modules ship `*falcos*.preset` files (`usr/lib/systemd/system-preset/` and `user-preset/`) in their `files/` overlays. 99-finalize.sh applies only those presets -- not `preset-all` -- so removing a module from [modules.kdl](../modules.kdl) removes its service enablement with it.

### Module finalize hooks

A module that needs run-once logic with real `systemctl` or the final image (service masking, `policy.json` edits) ships a `finalize.sh`; 99-finalize.sh sources them in modules.kdl order, flavor-gated, after systemctl is restored. See `core/auto-updates`.

### [Shared Libraries](../lib)

Shell helpers sourced by the build scripts, not run on their own: the module runner, download/verify helpers, kernel variant resolution, Secure Boot signing, DKMS module builds, hardened_malloc exemption wrappers, SELinux module install and os-release branding.
