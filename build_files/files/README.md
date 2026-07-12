[root](../../README.md) / [build_files](../README.md) / **files**

Static file trees copied verbatim into the image, each mirroring the target filesystem layout. systemd units, `/etc` and `/usr` config, wallpapers and icons.

### [Common Files](common)

### [Desktop Files](desktop)

### [Laptop Files](laptop)

## Notes

- `resolv-conf.conf` tmpfiles rule pins `/etc/resolv.conf` to the resolved stub — heals machines where the old dnsconfd image left a stale `127.0.0.1` resolv.conf behind and brakes DNS eg. when switching from a different bootc image like Bazzite or Aurora.
- `common/frequent/010-vpn.sh` removes the `resolvconf` -> `resolvectl` shim shipped by systemd-resolved, otherwise tailscaled misdetects it as a real resolvconf-style DNS manager and self-poisons `/etc/resolv.conf` on every boot (tailscale/tailscale#19062).

## Todo
