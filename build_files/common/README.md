[root](../../README.md) / [build_files](../README.md) / **common**

The build phases that run around the components. Flavor agnostic where possible so the layer cache is shared across desktop and laptop builds.

- [phase-setup.sh](phase-setup.sh) -- pre-install workarounds (systemctl stub, `/opt` shuffle) and `dnf5-plugins` for the component repo files. First RUN layer.
- [phase-flavor.sh](phase-flavor.sh) -- copies the `files/<flavor>` overlay and runs the [flavors/](../flavors) script. Runs after all components; the desktop/laptop layer cache forks here.
- [phase-finalize.sh](phase-finalize.sh) -- copies `files/common`, restores systemctl, regenerates the initramfs, relocates `/opt` payloads, merges the signing policy, applies the falcos systemd presets (see below) and the remaining baked tweaks (GRUB os-prober, composefs SELinux workaround). Last RUN layer, so edits to `files/common` never rebuild the layers above.

### Service enablement

Components ship `*falcos*.preset` files (`usr/lib/systemd/system-preset/` and `user-preset/`) in their `files/` overlays. phase-finalize.sh applies only those presets -- not `preset-all` -- so removing a component from [COMPONENTS.list](../../COMPONENTS.list) removes its service enablement with it.
