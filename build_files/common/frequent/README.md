[root](../../../README.md) / [build_files](../../README.md) / [common](../README.md) / **frequent**

Faster moving software shared by both flavors. Each script is sourced by phase-frequent.sh in build order. Pins come from the `versions-frequent-*.sh` files. Kept separate from core so frequent releases don't rebuild the expensive core layers. The flavor script (desktop.sh / laptop.sh) runs after these via phase-flavor.sh.

### [Pinned Tools](000-pinned-tools.sh) 

### [VPN](010-vpn.sh)

### [Custom Apps](020-custom-apps.sh)

### [Browser](030-browser.sh)

## Notes / Todo
