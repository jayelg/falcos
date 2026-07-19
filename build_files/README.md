[root](../README.md) / **build_files**

Everything that runs at image build time. These scripts are bind mounted into the build by the [Containerfile](../Containerfile), they are not copied into the final image (apart from the trees under Static Files).

### Components

Each component under `build_files/components/` is a self-describing, independently cacheable build unit. Components are toggleable via [COMPONENTS.list](../COMPONENTS.list). See the [components README](components/README.md) for a full listing.

### [Common Scripts](common)

Shared build infrastructure: the bootloader and SELinux baked steps, the repo-discovery step, and the flavor/finalize phases.

### [Static Files](files)

Config file trees copied verbatim into the image. systemd units, `/etc` and `/usr` config, wallpapers and icons, laid out to mirror the target filesystem. `common` applies to every build, the `desktop` and `laptop` overlays are copied per flavor.

### [Shared Libraries](lib)

Shell helpers sourced by the build scripts, not run on their own: kernel variant resolution, Secure Boot signing, DKMS module builds, hardened_malloc exemption wrappers and os-release branding.
