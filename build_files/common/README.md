[root](../../README.md) / [build_files](../README.md) / **common**

Package install scripts shared by both flavors, sourced by the phase scripts and grouped into themed layers by the [Containerfile](../../Containerfile). Kept flavor agnostic so the layer cache is shared across the desktop and laptop builds. The split is about build cache locality, foundational packages that rarely change stay in the earlier core layers, faster moving software sits in frequent so a bump doesn't rebuild core.

### [Core Packages](core)

Foundational, infrequently changed setup. Repos, KDE Plasma, the CachyOS kernel, hardware, security and hardening. Runs in the earliest and most expensive layers.

### [Frequent Packages](frequent)

Faster moving software. Pinned CLI tools, VPN clients, and web facing apps like browsers. Kept in later layers so a version bump here doesn't rebuild core.

## Notes / Todo

