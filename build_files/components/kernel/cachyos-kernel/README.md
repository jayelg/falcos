# cachyos-kernel:latest

CachyOS kernel replacing the stock Fedora kernel. Set `KERNEL=stock` build arg to keep the Fedora base kernel (fallback when the COPR is stale).

**Packages:** kernel-cachyos, kernel-cachyos-core, kernel-cachyos-modules, kernel-cachyos-devel-matched, ananicy-cpp, cachyos-settings, scx-scheds, bore-sysctl

**Requires:** `--mount=type=secret,id=mok_privkey` for Secure Boot module/vmlinuz signing (optional).
