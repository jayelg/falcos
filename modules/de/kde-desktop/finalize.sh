#!/bin/bash
# Finalize-stage hook: if plymouth is installed, rebuild the initramfs
# with the plymouth dracut module added so the boot splash and graphical
# disk passphrase prompt work.
#
# plymouth is installed by this module's own module.sh, so the rpm query
# is a cheap already-installed check rather than a probe of another
# module.

set -ouex pipefail

if rpm -q plymouth &>/dev/null; then
    KERNEL_PKG="$(cat /usr/lib/falcos/kernel-package 2>/dev/null || echo 'kernel-core')"
    KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' "$KERNEL_PKG")"

    export DRACUT_NO_XATTR=1
    dracut --force --no-hostonly --reproducible \
        --add "ostree crypt plymouth" \
        --kver "$KVER" \
        "/usr/lib/modules/${KVER}/initramfs.img"
fi
