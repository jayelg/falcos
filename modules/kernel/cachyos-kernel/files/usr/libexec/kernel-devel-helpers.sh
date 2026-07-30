#!/bin/bash
# Kernel-devel install and remove helpers, owned by the kernel module so
# the COPR and package names live with the only thing that knows them.
# Installed into the image by this module's files/ overlay; callers source
# it from /usr/libexec/kernel-devel-helpers.sh after the kernel module
# has run.

case "$KERNEL" in
    cachyos)
        KERNEL_DEVEL_PKG="kernel-cachyos-devel-matched"
        ;;
    stock)
        KERNEL_DEVEL_PKG="kernel-devel-matched"
        ;;
    *)
        echo "Unknown KERNEL='${KERNEL}' (expected cachyos or stock)" >&2
        exit 1
        ;;
esac

# <build deps...> — installs the matched devel headers plus the given
# build deps, enabling the kernel COPR only for the cachyos variant.
kernel_devel_install() {
    if [ "$KERNEL" = "cachyos" ]; then
        dnf5 -y copr enable bieszczaders/kernel-cachyos
        dnf5 -y install --enablerepo="copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos" \
            "$KERNEL_DEVEL_PKG" "$@"
    else
        dnf5 -y install "$KERNEL_DEVEL_PKG" "$@"
    fi
}

# <build deps...> — removes the devel headers and given build deps, and
# disables the COPR again.
kernel_devel_remove() {
    dnf5 -y remove --noautoremove "$KERNEL_DEVEL_PKG" "$@"
    if [ "$KERNEL" = "cachyos" ]; then
        dnf5 -y copr disable bieszczaders/kernel-cachyos
    fi
}
