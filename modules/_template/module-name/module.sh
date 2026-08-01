# module.sh — the module's install logic. OPTIONAL: delete this file
# for a pure-file module that only drops a files/ overlay (see base,
# auto-updates, vfio-passthrough).
#
# Everything below is a commented reference — uncomment and adapt the pieces
# you need, replacing <placeholders>. Sourced by lib/run-module.sh under
# `set -euo pipefail`, AFTER the repo file, so:
#   - strict mode is already on (a failing command aborts the build)
#   - $MODDIR points at this module's directory (/ctx/modules/...)
#   - every asset declared in module.kdl is in the environment as
#     $ASSET_<NAME>_VERSION / _URL / _SHA256, with the URL resolved on
#     the host ($ASSET_TEMPLATE_* below)
#   - every option declared in module.kdl is in $OPT_<NAME>, variant
#     overrides already folded in
#   - `systemctl` is STUBBED. Don't enable services here; ship a
#     45-module-<name>.preset in files/, or use finalize.sh.

### 1. Packages from the base repos
# dnf5 install -y <package-name> <another-package>

### 2. Packages from a third-party repo configured by the `repo` file.
# The repo is added disabled; enable it just for this install:
# dnf5 install -y --enablerepo='<repo-id>' <package-name>

# ─── lib/ helpers — source the ones you use ──────────────────────────────
# Sourcing a helper also tells shellcheck your $ASSET_* env may be
# externally defined, so it won't flag them (SC2154).

### fetch-helpers.sh — install the assets declared in module.kdl. The URL and
### the SHA256 both come from the pin, so neither is written out here.
# source /ctx/lib/fetch-helpers.sh
#
# fetch_install_bin <url> <sha256> <name> [path-in-archive]
#   Single-binary release -> /usr/bin/<name>. Archives are extracted first;
#   give [path-in-archive] when the binary isn't at the archive root.
# fetch_install_bin "$ASSET_TEMPLATE_URL" "$ASSET_TEMPLATE_SHA256" <tool>
#
# fetch_install_rpm <url> <sha256>
#   Download, verify and dnf-install an RPM.
# fetch_install_rpm "$ASSET_TEMPLATE_URL" "$ASSET_TEMPLATE_SHA256"
#
# fetch_extract <url> <sha256> <dir> [extractor args...]
#   Verify + extract into <dir>; extra args pass through (e.g. --strip-components=1).
# fetch_extract "$ASSET_TEMPLATE_URL" "$ASSET_TEMPLATE_SHA256" /tmp/src \
#     --strip-components=1
#
# fetch_verified <url> <sha256> <dest>
#   Just download + verify, keep the file at <dest> (you handle the rest).
# fetch_verified "$ASSET_TEMPLATE_URL" "$ASSET_TEMPLATE_SHA256" /tmp/asset
#
# The version is there too, for a path inside the archive:
# install -Dm755 "/tmp/src/lib<tool>.so.${ASSET_TEMPLATE_VERSION}" /usr/lib/...

### wrap-helpers.sh — for GUI/Electron apps that crash under the system-wide
### hardened_malloc LD_PRELOAD. Wraps the binary to drop the preload.
# source /ctx/lib/wrap-helpers.sh
# wrap_no_hardened_malloc /usr/bin/<binary>

### SELinux — the declarative way: drop a selinux/<name>.te file in this
### module (see selinux/example.te). run-module.sh auto-compiles and
### installs every selinux/*.te at priority 200; nothing is needed here.
###
### Only for a policy you must GENERATE at build time do it imperatively:
### write the .te to /tmp (the helper removes it, and the module dir is a
### read-only mount) then install it.
# source /ctx/lib/selinux-helpers.sh
# install_selinux_module /tmp/<generated>.te

### dkms-helpers.sh — build an out-of-tree kernel module (MOK-signed when a
### key is mounted). Needs the kernel headers and the signing key, so a
### module using this declares `requires "kernel-devel"`, `arg "KERNEL"`
### and `secret "mok_privkey"`; see hardware/gaming and looking-glass.
# source /ctx/lib/dkms-helpers.sh
# kernel_devel_install <extra-build-deps...>
# dkms_build_module <module-name> "$(dkms_conf_version "$MODDIR/src")" "$MODDIR/src"
# kernel_devel_remove <extra-build-deps...>
