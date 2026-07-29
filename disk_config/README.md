[root](../README.md) / **disk_config**

Configs for [bootc-image-builder](https://github.com/osbuild/bootc-image-builder), which turns the container image into installable disk and ISO images. Both are consumed by the [Build Disk Images](../.github/workflows/build-disk.yml) workflow and by the ISO and VM recipes in the [Justfile](../Justfile).

### [Disk Image Config](disk.toml)

Read as it is committed.

### [ISO / Installer Config](iso.template.toml)

A template. [Render installer config](../scripts/render-iso-config.sh) fills in the image the installed system is switched to and writes `build/iso.generated.toml`, which is the file bootc-image-builder reads. Both callers go through that script, so a local ISO installs the same reference CI publishes, and a fork's ISO points at the fork's own image.

The image is the ungated `falcos` build, by rule rather than by a declared value, and the namespace comes from [Registry](../scripts/registry.sh). Neither is written down here.

## Notes / Todo

