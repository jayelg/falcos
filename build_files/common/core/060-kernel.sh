### Kernel
# KERNEL=cachyos (default) replaces the stock Fedora kernel with the
# CachyOS build. KERNEL=stock keeps the Fedora base kernel untouched:
# the temporary fallback flipped by .github/workflows/kernel-freshness.yml
# when the COPR falls behind upstream stable. Fedora's kernel is signed
# with Fedora's Secure Boot key, which shim already trusts, so MOK
# signing then only matters for the out-of-tree modules built in
# 070-hardware.sh and the flavor scripts.
source /ctx/lib/kernel-helpers.sh

# Needed for module signing in later scripts, before phase-finalize.sh
# copies files/common
install -Dm644 /ctx/files/sb_cert.der /usr/share/falcos/sb_cert.der

if [ "$KERNEL" = "stock" ]; then
    echo "KERNEL=stock: keeping the Fedora base kernel, skipping CachyOS packages."
else
    # Runs early so everything downstream (dracut regen, DKMS builds,
    # firmware) targets the final kernel.
    dnf5 -y copr enable bieszczaders/kernel-cachyos
    dnf5 -y copr enable bieszczaders/kernel-cachyos-addons

    # Kernel and matched devel headers in one transaction, a version mismatch
    # breaks module signing/DKMS. noscripts because the package %posttrans runs
    # kernel-install/dracut before modules.dep exists and fails; depmod runs
    # explicitly below and phase-finalize.sh regenerates the real initramfs.
    dnf5 -y --setopt=tsflags=noscripts install --enablerepo="copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos" \
        kernel-cachyos \
        kernel-cachyos-core \
        kernel-cachyos-modules \
        kernel-cachyos-devel-matched

    # Companion packages: sched-ext schedulers, CachyOS sysctl/ananicy defaults
    dnf5 -y install --enablerepo="copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos-addons" \
        ananicy-cpp \
        cachyos-ananicy-rules \
        cachyos-settings \
        scx-scheds \
        scx-tools \
        bore-sysctl

    # bootc container lint hard-fails if more than one kernel is present
    dnf5 -y remove --noautoremove \
        kernel \
        kernel-core \
        kernel-modules \
        kernel-modules-core

    KVER="$(kver)"

    # noscripts above skipped depmod
    depmod "$KVER"

    dnf5 -y install sbsigntools openssl

    source /ctx/lib/sign-helpers.sh
    if mok_signing_available; then
        SIGN_FILE="/usr/src/kernels/${KVER}/scripts/sign-file"
        sign_modules_under "/usr/lib/modules/${KVER}" "$SIGN_FILE"
        sign_vmlinuz "/usr/lib/modules/${KVER}/vmlinuz"
    else
        echo "No MOK key supplied, kernel and modules are unsigned."
    fi

    dnf5 -y copr disable bieszczaders/kernel-cachyos
    dnf5 -y copr disable bieszczaders/kernel-cachyos-addons
    dnf5 -y remove --noautoremove kernel-cachyos-devel-matched sbsigntools
fi
