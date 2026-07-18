#!/bin/bash
# shellcheck disable=SC2034  # the dep arrays are consumed by the sourcing scripts
# DKMS module build helper, sourced by scripts that compile an out-of-tree
# module (xone in common/core/070-hardware.sh, kvmfr in desktop.sh).
# Callers handle kernel_devel_install/remove and any module-specific
# extras (modprobe configs, firmware, udev rules).

source "$(dirname "${BASH_SOURCE[0]}")/kernel-helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/sign-helpers.sh"

# Shared build deps for kernel_devel_install/kernel_devel_remove. The remove
# list is smaller on purpose: git is a permanent package owned by
# common/core/040-dev-tools.sh and openssl ships in the fedora-bootc base,
# so removing either would strip a package the image wants. Callers append
# module-specific extras (e.g. cabextract for xone) to both calls.
DKMS_BUILD_DEPS=(dkms gcc make git sbsigntools openssl)
DKMS_BUILD_DEPS_REMOVE=(dkms gcc make sbsigntools)

# <src-dir> — prints PACKAGE_VERSION from the dkms.conf in <src-dir>
dkms_conf_version() {
    local version
    version="$(sed -n 's/^PACKAGE_VERSION="\([^"]*\)"/\1/p' "$1/dkms.conf")"
    if [ -z "$version" ]; then
        echo "no PACKAGE_VERSION in $1/dkms.conf" >&2
        return 1
    fi
    echo "$version"
}

# <name> <version> <src-dir> — copies <src-dir> to /usr/src, then builds
# and installs the module for the image kernel, MOK-signed when a key is
# mounted. Cleans up after itself: the throwaway key DKMS would otherwise
# bake into the image, and the build state bootc lint flags as unmanaged
# /var content.
dkms_build_module() {
    local name="$1" version="$2" src="$3"
    local kver
    kver="$(kver)"

    configure_dkms_signing
    if ! mok_signing_available; then
        echo "No MOK key supplied, ${name} modules are unsigned."
    fi

    rm -rf "/usr/src/${name}-${version}"
    cp -a "$src" "/usr/src/${name}-${version}"
    dkms add -m "$name" -v "$version"
    dkms build -m "$name" -v "$version" -k "$kver"
    dkms install -m "$name" -v "$version" -k "$kver" --force

    # Never leave a DKMS-generated signing key in the image
    rm -f /var/lib/dkms/mok.key /var/lib/dkms/mok.pub
    # bootc lint flags the DKMS build cache as unmanaged /var content
    rm -rf "/var/lib/dkms/${name}" "/usr/src/${name}-${version}"
}
