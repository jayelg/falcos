[root](../../README.md) / [build_files](../README.md) / **flavors**

Per-flavor build scripts, run by [common/phase-flavor.sh](../common/phase-flavor.sh) after all components. Branding only, plus pointers to where the flavor's hardware config lives:

- [desktop.sh](desktop.sh) -- desktop branding; VFIO passthrough config ships in [files/desktop](../files/desktop), the kvmfr module is the desktop-gated looking-glass component
- [laptop.sh](laptop.sh) -- laptop branding
