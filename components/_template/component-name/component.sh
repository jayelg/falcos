# component.sh — the component's install logic. OPTIONAL: delete this file
# for a pure-file component that only drops a files/ overlay (see base,
# auto-updates, vfio-passthrough).
#
# Everything below is a commented reference — uncomment and adapt the pieces
# you need, replacing <placeholders>. Sourced by lib/run-component.sh under
# `set -euo pipefail`, AFTER repo and versions.sh, so:
#   - strict mode is already on (a failing command aborts the build)
#   - $COMPDIR points at this component's directory (/ctx/components/...)
#   - version pins from versions.sh are in scope ($TEMPLATE_* below)
#   - variant overrides from variants/<v>.sh are already applied
#   - `systemctl` is STUBBED. Don't enable services here; ship a
#     45-falcos-<name>.preset in files/, or use finalize.sh.

### 1. Packages from the base repos
# dnf5 install -y <package-name> <another-package>

### 2. Packages from a third-party repo configured by the `repo` file.
# The repo is added disabled; enable it just for this install:
# dnf5 install -y --enablerepo='<repo-id>' <package-name>

# ─── lib/ helpers — source the ones you use ──────────────────────────────
# Sourcing a helper also tells shellcheck your $TEMPLATE_* pins may be
# externally defined, so it won't flag them (SC2154).

### fetch-helpers.sh — install pinned upstream release assets. Every asset is
### SHA256-verified against the pin in versions.sh.
# source /ctx/lib/fetch-helpers.sh
#
# fetch_install_bin <url> <sha256> <name> [path-in-archive]
#   Single-binary release -> /usr/bin/<name>. Archives are extracted first;
#   give [path-in-archive] when the binary isn't at the archive root.
# fetch_install_bin "https://example.com/<tool>-${TEMPLATE_VERSION}.tar.gz" \
#     "$TEMPLATE_SHA256" <tool>
#
# fetch_install_rpm <url> <sha256>
#   Download, verify and dnf-install an RPM.
# fetch_install_rpm "https://example.com/<pkg>-${TEMPLATE_VERSION}.rpm" "$TEMPLATE_SHA256"
#
# fetch_extract <url> <sha256> <dir> [extractor args...]
#   Verify + extract into <dir>; extra args pass through (e.g. --strip-components=1).
# fetch_extract "https://example.com/<src>-${TEMPLATE_VERSION}.tar.gz" \
#     "$TEMPLATE_SHA256" /tmp/src --strip-components=1
#
# fetch_verified <url> <sha256> <dest>
#   Just download + verify, keep the file at <dest> (you handle the rest).
# fetch_verified "https://example.com/<asset>" "$TEMPLATE_SHA256" /tmp/asset

### wrap-helpers.sh — for GUI/Electron apps that crash under the system-wide
### hardened_malloc LD_PRELOAD. Wraps the binary to drop the preload.
# source /ctx/lib/wrap-helpers.sh
# wrap_no_hardened_malloc /usr/bin/<binary>

### SELinux — the declarative way: drop a selinux/<name>.te file in this
### component (see selinux/example.te). run-component.sh auto-compiles and
### installs every selinux/*.te at priority 200; nothing is needed here.
###
### Only for a policy you must GENERATE at build time do it imperatively:
### write the .te to /tmp (the helper removes it, and the component dir is a
### read-only mount) then install it.
# source /ctx/lib/selinux-helpers.sh
# install_selinux_module /tmp/<generated>.te

### dkms-helpers.sh — build an out-of-tree kernel module (MOK-signed when a
### key is mounted). Needs the kernel headers, so a component using this also
### needs a Containerfile.part; see hardware/gaming and looking-glass.
# source /ctx/lib/dkms-helpers.sh
# kernel_devel_install <extra-build-deps...>
# dkms_build_module <module-name> "$(dkms_conf_version "$COMPDIR/src")" "$COMPDIR/src"
# kernel_devel_remove <extra-build-deps...>
