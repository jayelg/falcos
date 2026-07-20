[root](../README.md) / **build_files**

Everything that runs at image build time. These scripts are bind mounted into the build by the [Containerfile](../Containerfile), they are not copied into the final image (apart from the component `files/` overlays).

### [Components](components)

Self-describing, independently cacheable build units, one Containerfile RUN layer each. What gets built is controlled by [COMPONENTS.list](../COMPONENTS.list): edit the list, run `just generate`, commit both. Each layer runs [lib/run-component.sh](lib/run-component.sh), which handles the shared conventions (repo file, version pins, variants, `files/` overlay, justfile recipes).

### Phase Scripts

The build phases around the components, numbered to show their order relative to the component RUN layers that sit between them:

- [00-setup.sh](00-setup.sh) -- pre-install workarounds (systemctl stub, `/opt` shuffle) and `dnf5-plugins` for the component repo files. First RUN layer.
- [50-flavor.sh](50-flavor.sh) -- applies os-release branding (NAME, PRETTY_NAME, DEFAULT_HOSTNAME) via [lib/brand-helpers.sh](lib/brand-helpers.sh). Runs after all components; the desktop/laptop layer cache forks here. Flavor-specific files ship in flavor-gated components (e.g. `vfio-passthrough`, `laptop-tweaks`).
- [99-finalize.sh](99-finalize.sh) -- restores systemctl, regenerates the initramfs, relocates `/opt` payloads, applies the falcos systemd presets, runs per-component `finalize.sh` hooks, and the remaining global tweaks (GRUB os-prober, composefs SELinux workaround). Last RUN layer.

### Service enablement

Components ship `*falcos*.preset` files (`usr/lib/systemd/system-preset/` and `user-preset/`) in their `files/` overlays. 99-finalize.sh applies only those presets -- not `preset-all` -- so removing a component from [COMPONENTS.list](../COMPONENTS.list) removes its service enablement with it.

### Component finalize hooks

A component that needs run-once logic with real `systemctl` or the final image (service masking, `policy.json` edits) ships a `finalize.sh`; 99-finalize.sh sources them in COMPONENTS.list order, flavor-gated, after systemctl is restored. See `core/auto-updates`.

### [Shared Libraries](lib)

Shell helpers sourced by the build scripts, not run on their own: the component runner, download/verify helpers, kernel variant resolution, Secure Boot signing, DKMS module builds, hardened_malloc exemption wrappers, SELinux module install and os-release branding.
