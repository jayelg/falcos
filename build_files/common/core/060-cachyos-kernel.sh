### CachyOS kernel
# Swaps the stock Fedora kernel for CachyOS's (BORE/EEVDF scheduler,
# sched-ext, improved BFQ/BTRFS/XFS/ZSTD). Its AMD-specific features are
# no-ops on Intel hardware; the rest still applies.
#
# Runs early so everything downstream (dracut regen, DKMS builds, firmware)
# targets the final kernel.
dnf5 -y copr enable bieszczaders/kernel-cachyos
dnf5 -y copr enable bieszczaders/kernel-cachyos-addons

# Kernel + matched devel headers in one transaction, or a version mismatch
# breaks module signing/DKMS later. --setopt=tsflags=noscripts: the
# package's own %posttrans tries to run kernel-install/dracut before
# modules.dep exists and fails outright ("did you run depmod?"); depmod is
# run explicitly below instead, and phase-finalize.sh's own dracut regen at
# the end of the build produces the real initramfs.
dnf5 -y --setopt=tsflags=noscripts install --enablerepo="copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos" \
    kernel-cachyos \
    kernel-cachyos-core \
    kernel-cachyos-modules \
    kernel-cachyos-devel-matched

# Companion packages tuned for this kernel: sched-ext schedulers, CachyOS's
# sysctl/ananicy defaults.
dnf5 -y install --enablerepo="copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos-addons" \
    ananicy-cpp \
    cachyos-ananicy-rules \
    cachyos-settings \
    scx-scheds \
    scx-tools \
    bore-sysctl

# bootc container lint hard-fails if more than one kernel is present under
# /usr/lib/modules.
dnf5 -y remove --noautoremove \
    kernel \
    kernel-core \
    kernel-modules \
    kernel-modules-core

KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-cachyos-core)"

# noscripts above skipped depmod; DKMS builds later keep modules.dep updated
# themselves via their own `dkms install`.
depmod "$KVER"

dnf5 -y install sbsigntools openssl

# sb_cert.der isn't copied from files/common until phase-finalize.sh (see
# Containerfile) — signing here and in 080-xone-dkms.sh both need it now,
# so install it directly from its own narrow mount instead.
install -Dm644 /ctx/files/sb_cert.der /usr/share/falcos/sb_cert.der

source /ctx/lib/sign-helpers.sh
if mok_signing_available; then
    SIGN_FILE="/usr/src/kernels/${KVER}/scripts/sign-file"
    sign_modules_under "/usr/lib/modules/${KVER}" "$SIGN_FILE"
    sign_vmlinuz "/usr/lib/modules/${KVER}/vmlinuz"
else
    echo "No MOK key supplied — kernel and modules are unsigned."
fi

dnf5 -y copr disable bieszczaders/kernel-cachyos
dnf5 -y copr disable bieszczaders/kernel-cachyos-addons
dnf5 -y remove --noautoremove kernel-cachyos-devel-matched sbsigntools
