[root](../../README.md) / [build_files](../README.md) / **lib**

Shell helpers sourced by the build scripts, not run on their own (except `run-component.sh`, the entry point the generated Containerfile blocks call).

### [Component Runner](run-component.sh)

Runs one component per RUN layer: flavor gate, repo file, `versions.sh` pins, variant overrides, `component.sh`, `files/` overlay, `justfile.inc` append. Keeps the per-component conventions in one place.

### [Fetch Helpers](fetch-helpers.sh)

Download-verify-install for pinned upstream release assets: `fetch_verified`, `fetch_extract`, `fetch_install_bin`, `fetch_install_rpm`. Every asset is SHA256-checked against the component's `versions.sh`.

### [Kernel Helpers](kernel-helpers.sh)

Resolves the kernel variant (`KERNEL=cachyos` or `stock`) into package names, and installs/removes the matched devel headers plus module build deps.

### [Signing Helpers](sign-helpers.sh)

Secure Boot (MOK) signing for the kernel image and kernel modules. Signing is optional: without a mounted key, callers skip it.

### [DKMS Helpers](dkms-helpers.sh)

Builds and installs an out-of-tree module via DKMS (used for xone and kvmfr), signed when a MOK key is available, and cleans up the build state bootc lint would flag. Sources the kernel and signing helpers itself.

### [Wrap Helpers](wrap-helpers.sh)

Wraps a binary to strip the system-wide hardened_malloc `LD_PRELOAD` for apps that crash under it. Standalone so RUN layers can mount just this file.

### [SELinux Helpers](selinux-helpers.sh)

Compiles and installs a local SELinux policy module from a `.te` file into the targeted store. Standalone so RUN layers can mount just this file.

### [Brand Helpers](brand-helpers.sh)

Patches the branding fields of `/etc/os-release`, parameterized per flavor.

## Caution

Every component layer bind-mounts this directory, so editing any file here rebuilds all component layers in CI. Keep it small and stable; batch helper changes.
