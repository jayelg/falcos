[root](../README.md) / **build_files**

Everything that runs at image build time. These scripts are bind mounted into the build by the [Containerfile](../Containerfile), they are not copied into the final image (apart from the trees under Static Files and the component `files/` overlays).

### [Components](components)

Self-describing, independently cacheable build units, one Containerfile RUN layer each. What gets built is controlled by [COMPONENTS.list](../COMPONENTS.list): edit the list, run `just generate`, commit both. Each layer runs [lib/run-component.sh](lib/run-component.sh), which handles the shared conventions (repo file, version pins, variants, `files/` overlay, justfile recipes).

### Phase Scripts

The build phases around the components, numbered to show their order relative to the component RUN layers that sit between them:

- [00-setup.sh](00-setup.sh) -- pre-install workarounds (systemctl stub, `/opt` shuffle) and `dnf5-plugins` for the component repo files. First RUN layer.
- [50-flavor.sh](50-flavor.sh) -- copies the `files/<flavor>` overlay and applies os-release branding (NAME, PRETTY_NAME, DEFAULT_HOSTNAME) via [lib/brand-helpers.sh](lib/brand-helpers.sh). Runs after all components; the desktop/laptop layer cache forks here.
- [99-finalize.sh](99-finalize.sh) -- copies `files/common`, restores systemctl, regenerates the initramfs, relocates `/opt` payloads, merges the signing policy, applies the falcos systemd presets and the remaining baked tweaks (GRUB os-prober, composefs SELinux workaround). Last RUN layer, so edits to `files/common` never rebuild the layers above.

### Service enablement

Components ship `*falcos*.preset` files (`usr/lib/systemd/system-preset/` and `user-preset/`) in their `files/` overlays. 99-finalize.sh applies only those presets -- not `preset-all` -- so removing a component from [COMPONENTS.list](../COMPONENTS.list) removes its service enablement with it.

### [Static Files](files)

Config file trees copied verbatim into the image. `common` applies to every build (copied in 99-finalize), the `desktop` and `laptop` overlays are copied per flavor (50-flavor). Files owned by a single component live in that component's `files/` directory instead.

### [Shared Libraries](lib)

Shell helpers sourced by the build scripts, not run on their own: the component runner, download/verify helpers, kernel variant resolution, Secure Boot signing, DKMS module builds, hardened_malloc exemption wrappers, SELinux module install and os-release branding.
