#!/bin/bash
# Finalize-stage hook: builds the initramfs for the image kernel, once.
# Runs after every module has installed and systemctl is restored, so
# dracut sees the final set of kernel modules.
#
# The dracut module set is data rather than hook order. ostree and crypt
# are what booting this image needs at all; everything else arrives in the
# file this module collects, one fragment per module that needs something
# in the initramfs (plymouth, from the desktop, is the only one today).
# Each fragment is appended during its own module's layer, so the set is
# complete before any finalize hook runs and no hook has to run before or
# after another.

set -ouex pipefail

KERNEL_PKG="$(cat /usr/lib/falcos/kernel-package 2>/dev/null || echo 'kernel-core')"
KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' "$KERNEL_PKG")"

# /usr/lib/falcos/dracut.modules is an aggregate of every module's
# dracut.modules, assembled at build time by run-module.sh. One dracut
# module name per line; blank lines and # comments are ignored.
DRACUT_MODULES=(ostree crypt)
COLLECTED="/usr/lib/falcos/dracut.modules"
if [ -f "$COLLECTED" ]; then
    while IFS= read -r name; do
        [[ -z "$name" || "$name" == \#* ]] && continue
        DRACUT_MODULES+=("$name")
    done < "$COLLECTED"
fi

export DRACUT_NO_XATTR=1
dracut --force --no-hostonly --reproducible \
    --add "${DRACUT_MODULES[*]}" \
    --kver "$KVER" \
    "/usr/lib/modules/${KVER}/initramfs.img"
