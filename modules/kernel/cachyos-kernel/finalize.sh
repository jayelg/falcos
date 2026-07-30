#!/bin/bash
# Finalize-stage hook: regenerates the initramfs for the image kernel.
# Runs after every module has installed and systemctl is restored, so
# dracut sees the final set of kernel modules.
#
# plymouth is left to the desktop module's finalize hook — the kernel
# does not know about desktop environment details.

set -ouex pipefail

KERNEL_PKG="$(cat /usr/lib/falcos/kernel-package 2>/dev/null || echo 'kernel-core')"
KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' "$KERNEL_PKG")"

export DRACUT_NO_XATTR=1
dracut --force --no-hostonly --reproducible \
    --add "ostree crypt" \
    --kver "$KVER" \
    "/usr/lib/modules/${KVER}/initramfs.img"
