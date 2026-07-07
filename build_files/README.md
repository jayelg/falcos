[root](../README.md) / **build_files**

Everything that runs at image build time. These scripts are bind mounted into the build by the [Containerfile](../Containerfile), they are not copied into the final image (apart from the trees under Static Files). The build runs in ordered phases (setup, core, frequent, flavor, finalize), each driven by a `phase-*.sh` script. Every themed group of scripts is its own layer, so a change only busts that group's cache.

### [Common Scripts](common)

The package install scripts shared by both flavors. Split into core (foundational or rarely changed) and frequent (faster moving software and software requiring frequent security updates) so a version bump in fast moving software doesn't rebuild the expensive core layers. Flavour agnostic so the layer cache is shared across the desktop and laptop builds.

### [Static Files](files)

Config file trees copied verbatim into the image. systemd units, `/etc` and `/usr` config, wallpapers and icons, laid out to mirror the target filesystem. `common` applies to every build, the `desktop` and `laptop` overlays are copied per flavor.

### [Shared Libraries](lib)

Shell helpers sourced by the build scripts, not run on their own. Currently just the Secure Boot signing helpers used by the kernel and DKMS scripts.

## Notes / Todo

