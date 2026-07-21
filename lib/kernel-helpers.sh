#!/bin/bash
# Kernel-variant helpers, sourced by scripts that install the kernel or
# build modules against it. KERNEL=cachyos (default) targets the CachyOS
# COPR kernel; KERNEL=stock keeps the Fedora base kernel and is the
# temporary fallback flipped by .github/workflows/kernel-freshness.yml
# when the COPR falls behind upstream stable point releases.

KERNEL="${KERNEL:-cachyos}"
case "$KERNEL" in
    cachyos)
        KERNEL_CORE_PKG="kernel-cachyos-core"
        KERNEL_DEVEL_PKG="kernel-cachyos-devel-matched"
        ;;
    stock)
        KERNEL_CORE_PKG="kernel-core"
        KERNEL_DEVEL_PKG="kernel-devel-matched"
        ;;
    *)
        echo "Unknown KERNEL='${KERNEL}' (expected cachyos or stock)" >&2
        exit 1
        ;;
esac

kver() {
    rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' "$KERNEL_CORE_PKG"
}

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
