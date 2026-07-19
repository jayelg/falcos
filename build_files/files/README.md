[root](../../README.md) / [build_files](../README.md) / **files**

Static file trees copied verbatim into the image, each mirroring the target filesystem layout. systemd units, `/etc` and `/usr` config, wallpapers and icons.

Files owned by a single component (its units, presets, tmpfiles, udev rules) live in that component's `files/` directory instead and are copied in the component's own layer; the trees here are for cross-cutting or flavor-specific config only.

### [Common Files](common)

Copied by phase-finalize.sh in the last layer, so edits here never rebuild the component layers.

### [Desktop Files](desktop) / [Laptop Files](laptop)

Flavor overlays, copied by phase-flavor.sh. The desktop overlay carries the VFIO GPU-passthrough config (kargs, modprobe, dracut config, rebind unit + preset).

## Notes

- `common/usr/lib/tmpfiles.d/resolv-conf.conf` pins `/etc/resolv.conf` to the resolved stub — heals machines where an older dnsconfd-shipping image left a stale `127.0.0.1` resolv.conf behind, e.g. when switching from a different bootc image like Bazzite or Aurora.
