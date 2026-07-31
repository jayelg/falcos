[root](../README.md) / **build-phases**

Everything that runs at image build time. These scripts are bind mounted into the build by the [Containerfile skeleton](../scripts/Containerfile.skeleton), they are not copied into the final image (apart from the module `files/` overlays).

### [Modules](../modules)

Self-describing, independently cacheable build units, one Containerfile RUN layer each. What gets built is controlled by [image.kdl](../image.kdl): edit the list, run `just generate`, commit both. Each layer runs [lib/run-module.sh](../lib/run-module.sh), which handles the shared conventions (repo file, `module.sh`, SELinux policy, `files/` overlay, collected files).

### Phase Scripts

A drop-in directory: every `*.sh` here becomes one RUN layer, in the order its number gives it. **The module layers build at 50**, so a phase numbered below that runs before them and one at or above runs after. Adding a phase is adding a file — `just generate` picks it up, and a name without a number is a lint failure rather than a guess.

- [00-setup.sh](00-setup.sh) -- pre-install workarounds (systemctl stub, `/opt` shuffle) and `dnf5-plugins` for the module repo files. First RUN layer.
- [50-flavor.sh](50-flavor.sh) -- applies os-release branding (NAME, PRETTY_NAME, DEFAULT_HOSTNAME) via [lib/brand-helpers.sh](../lib/brand-helpers.sh). Runs after all modules; the desktop/laptop layer cache forks here. Flavor-specific files ship in flavor-gated modules (e.g. `virtualization/vfio-passthrough`, `hardware/laptop-tweaks`).
- [99-finalize.sh](99-finalize.sh) -- restores systemctl, relocates `/opt` payloads, applies the falcos systemd presets, runs per-module `finalize.sh` hooks, and the remaining global tweaks (GRUB os-prober, composefs SELinux workaround). Last RUN layer. The initramfs is built by the kernel module's hook, not here.

What a phase gets depends on which side of the modules it is on, because the difference is a property of the build rather than of the script:

| | above the modules | below the modules |
| --- | --- | --- |
| mounts | its own script, `/var/cache`, `/var/log`, `/tmp` | the same, plus [lib/](../lib) and [modules/](../modules) |
| env | none | `FLAVOR`, `IMAGE_VERSION`, `FINALIZE_ORDER` |

A phase above the modules gets neither because `ARG FLAVOR` and `ARG IMAGE_VERSION` are declared below them on purpose (an ARG in scope is part of the cache key of every RUN under it), and because binding the module tree into the first layer of the build would put every module's content in that layer's cache key.

### Service enablement

Modules ship `*falcos*.preset` files (`usr/lib/systemd/system-preset/` and `user-preset/`) in their `files/` overlays. 99-finalize.sh applies only those presets -- not `preset-all` -- so removing a module from [image.kdl](../image.kdl) removes its service enablement with it.

### Module finalize hooks

A module that needs run-once logic with real `systemctl` or the final image (service masking, `policy.json` edits) ships a `finalize.sh`; 99-finalize.sh sources them in image.kdl order, flavor-gated, after systemctl is restored. See `core/auto-updates`.

Order between hooks is deliberately not a thing a module can rely on. Two modules that both need something done to the same artifact share a collected file instead: the kernel module's hook builds the initramfs from `dracut.modules`, which any module can contribute a name to.

### [Shared Libraries](../lib)

Shell helpers sourced by the build scripts, not run on their own: the module runner, download/verify helpers, kernel variant resolution, Secure Boot signing, DKMS module builds, hardened_malloc exemption wrappers, SELinux module install and os-release branding.
