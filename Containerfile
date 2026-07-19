# CI builds with BuildKit (docker/build-push-action)
FROM scratch AS ctx
COPY build_files /

# Base Image
# No digest pin: quay.io/fedora prunes old untagged manifests within days,
# so a pinned digest 404s before the next Renovate bump lands.
FROM quay.io/fedora/fedora-bootc:44

### [IM]MUTABLE /opt
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt


RUN --mount=type=bind,from=ctx,source=/phase-setup.sh,target=/ctx/phase-setup.sh \
    /ctx/phase-setup.sh

### Repo Discovery (baked, idempotent)
# Sources every component repo file. Each declares REPO_ID for idempotency:
# the loop skips repos already configured on disk.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    dnf5 install -y dnf5-plugins && \
    for repo in /ctx/components/*/repo /ctx/components/*/*/repo; do
        [ -f "$repo" ] || continue
        REPO_ID="$(sed -n 's/^REPO_ID="\(.*\)"/\1/p' "$repo")"
        if [ -n "$REPO_ID" ] && [ -f "/etc/yum.repos.d/${REPO_ID}.repo" ]; then
            echo "Repo ${REPO_ID} already configured, skipping"
            continue
        fi
        source "$repo"
    done

## Components (per-component RUN layers for independent BuildKit caching)

# ---- Component: kde-desktop:latest ----
RUN --mount=type=bind,from=ctx,source=/components/de/kde-desktop,target=/ctx/components/de/kde-desktop \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=latest bash /ctx/components/de/kde-desktop/component.sh

# ---- Component: kde-theming:latest ----
RUN --mount=type=bind,from=ctx,source=/components/de/kde-theming,target=/ctx/components/de/kde-theming \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=latest bash /ctx/components/de/kde-theming/component.sh

# ---- Component: cli-tools:latest ----
RUN --mount=type=bind,from=ctx,source=/components/core/cli-tools,target=/ctx/components/core/cli-tools \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=latest bash /ctx/components/core/cli-tools/component.sh

# ---- Component: dev-tools:latest ----
RUN --mount=type=bind,from=ctx,source=/components/core/dev-tools,target=/ctx/components/core/dev-tools \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=latest bash /ctx/components/core/dev-tools/component.sh

# ---- Component: falcos-bootc-updates:0.1.1 ----
RUN --mount=type=bind,from=ctx,source=/components/core/falcos-bootc-updates,target=/ctx/components/core/falcos-bootc-updates \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=0.1.1 bash /ctx/components/core/falcos-bootc-updates/component.sh

# ---- Component: pinned-cli-tools:latest ----
RUN --mount=type=bind,from=ctx,source=/components/core/pinned-cli-tools,target=/ctx/components/core/pinned-cli-tools \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=latest bash /ctx/components/core/pinned-cli-tools/component.sh

# cachyos (default) or stock. stock keeps the Fedora base kernel and is
# the temporary fallback flipped by .github/workflows/kernel-freshness.yml
# when the CachyOS COPR goes stale; see build_files/lib/kernel-helpers.sh.
ARG KERNEL=cachyos

# ---- Component: cachyos-kernel:latest ----
RUN --mount=type=bind,from=ctx,source=/components/kernel/cachyos-kernel,target=/ctx/components/kernel/cachyos-kernel \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=bind,from=ctx,source=/files/common/usr/share/falcos/sb_cert.der,target=/ctx/files/sb_cert.der \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    --mount=type=secret,id=mok_privkey,target=/run/secrets/mok_privkey,required=false \
    KERNEL=${KERNEL} COMPONENT_VERSION=latest bash /ctx/components/kernel/cachyos-kernel/component.sh

# ---- Component: firmware:latest ----
RUN --mount=type=bind,from=ctx,source=/components/hardware/firmware,target=/ctx/components/hardware/firmware \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=latest bash /ctx/components/hardware/firmware/component.sh

# ---- Component: gaming:latest ----
RUN --mount=type=bind,from=ctx,source=/components/hardware/gaming,target=/ctx/components/hardware/gaming \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    --mount=type=secret,id=mok_privkey,target=/run/secrets/mok_privkey,required=false \
    COMPONENT_VERSION=latest bash /ctx/components/hardware/gaming/component.sh

# ---- Component: hardware-tools:latest ----
RUN --mount=type=bind,from=ctx,source=/components/hardware/tools,target=/ctx/components/hardware/tools \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=latest bash /ctx/components/hardware/tools/component.sh

# ---- Component: multimedia:latest ----
RUN --mount=type=bind,from=ctx,source=/components/multimedia,target=/ctx/components/multimedia \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=latest bash /ctx/components/multimedia/component.sh

# ---- Component: networking:latest ----
RUN --mount=type=bind,from=ctx,source=/components/networking,target=/ctx/components/networking \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=latest bash /ctx/components/networking/component.sh

# ---- Component: libvirt:latest ----
RUN --mount=type=bind,from=ctx,source=/components/virtualization/libvirt,target=/ctx/components/virtualization/libvirt \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=latest bash /ctx/components/virtualization/libvirt/component.sh

# ---- Component: incus:latest ----
RUN --mount=type=bind,from=ctx,source=/components/virtualization/incus,target=/ctx/components/virtualization/incus \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=latest bash /ctx/components/virtualization/incus/component.sh

# ---- Component: podman:latest ----
RUN --mount=type=bind,from=ctx,source=/components/virtualization/podman,target=/ctx/components/virtualization/podman \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=latest bash /ctx/components/virtualization/podman/component.sh

# ---- Component: security:latest ----
RUN --mount=type=bind,from=ctx,source=/components/security,target=/ctx/components/security \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=latest bash /ctx/components/security/component.sh

# ---- Component: hardened-malloc:latest ----
RUN --mount=type=bind,from=ctx,source=/components/hardening/hardened-malloc,target=/ctx/components/hardening/hardened-malloc \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=latest bash /ctx/components/hardening/hardened-malloc/component.sh

# ---- Component: sudo-hardening:latest ----
RUN --mount=type=bind,from=ctx,source=/components/hardening/sudo-hardening,target=/ctx/components/hardening/sudo-hardening \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=latest bash /ctx/components/hardening/sudo-hardening/component.sh

# ---- Component: affinity:3.2.0 ----
RUN --mount=type=bind,from=ctx,source=/components/apps/affinity,target=/ctx/components/apps/affinity \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=3.2.0 bash /ctx/components/apps/affinity/component.sh

# ---- Component: trivalent:latest ----
RUN --mount=type=bind,from=ctx,source=/components/apps/trivalent,target=/ctx/components/apps/trivalent \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=latest bash /ctx/components/apps/trivalent/component.sh

# ---- Component: mullvad-vpn:latest ----
RUN --mount=type=bind,from=ctx,source=/components/vpn/mullvad-vpn,target=/ctx/components/vpn/mullvad-vpn \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=latest bash /ctx/components/vpn/mullvad-vpn/component.sh

# ---- Component: netbird:latest ----
RUN --mount=type=bind,from=ctx,source=/components/vpn/netbird,target=/ctx/components/vpn/netbird \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=latest bash /ctx/components/vpn/netbird/component.sh

# ---- Component: tailscale:latest ----
RUN --mount=type=bind,from=ctx,source=/components/vpn/tailscale,target=/ctx/components/vpn/tailscale \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=latest bash /ctx/components/vpn/tailscale/component.sh

# ---- Component: plasma-network-audio:v0.1-alpha.1 ----
RUN --mount=type=bind,from=ctx,source=/components/de/plasma-network-audio,target=/ctx/components/de/plasma-network-audio \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    COMPONENT_VERSION=v0.1-alpha.1 bash /ctx/components/de/plasma-network-audio/component.sh

### Baked Steps

### Bootloader
RUN echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub

### Kernel Stale-Management
# bootc container lint hard-fails if more than one kernel is present.
# Runs after the cachyos-kernel component.
RUN if rpm -q kernel-cachyos-core &>/dev/null; then \
        dnf5 -y remove --noautoremove kernel kernel-core kernel-modules kernel-modules-core; \
    fi

### SELinux Policy: composefs/overlay execmem workaround
# A composefs/overlay mmap bug mislabels legitimate userspace execmem
# mappings as kernel_t (ublue-os/akmods#537). Drop once fixed upstream.
RUN --mount=type=bind,from=ctx,source=/lib/selinux-helpers.sh,target=/ctx/lib/selinux-helpers.sh \
    cat <<'EOF' > /tmp/composefs_execmem.te
module composefs_execmem 0.1;

require {
	type kernel_t;
	class process execmem;
}

allow kernel_t self:process execmem;
EOF
    source /ctx/lib/selinux-helpers.sh && install_selinux_module /tmp/composefs_execmem.te

ARG FLAVOR=laptop
# CI passes the YYYYMMDD build date; local builds get it from `just build`
ARG IMAGE_VERSION=dev

# Union of both flavors' helpers: brand for laptop and desktop, dkms (which
# sources kernel- and sign-helpers) for desktop's kvmfr module.
RUN --mount=type=bind,from=ctx,source=/phase-flavor.sh,target=/ctx/phase-flavor.sh \
    --mount=type=bind,from=ctx,source=/versions-frequent-desktop.sh,target=/ctx/versions-frequent-desktop.sh \
    --mount=type=bind,from=ctx,source=/lib/brand-helpers.sh,target=/ctx/lib/brand-helpers.sh \
    --mount=type=bind,from=ctx,source=/lib/dkms-helpers.sh,target=/ctx/lib/dkms-helpers.sh \
    --mount=type=bind,from=ctx,source=/lib/kernel-helpers.sh,target=/ctx/lib/kernel-helpers.sh \
    --mount=type=bind,from=ctx,source=/lib/sign-helpers.sh,target=/ctx/lib/sign-helpers.sh \
    --mount=type=bind,from=ctx,source=/${FLAVOR}.sh,target=/ctx/${FLAVOR}.sh \
    --mount=type=bind,from=ctx,source=/files/${FLAVOR},target=/ctx/files/${FLAVOR} \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    --mount=type=secret,id=mok_privkey,target=/run/secrets/mok_privkey,required=false \
    FLAVOR=${FLAVOR} KERNEL=${KERNEL} IMAGE_VERSION=${IMAGE_VERSION} /ctx/phase-flavor.sh

RUN --mount=type=bind,from=ctx,source=/phase-finalize.sh,target=/ctx/phase-finalize.sh \
    --mount=type=bind,from=ctx,source=/enable-services.sh,target=/ctx/enable-services.sh \
    --mount=type=bind,from=ctx,source=/files/common,target=/ctx/files/common \
    /ctx/phase-finalize.sh

### SIGNING POLICY
## Bake cosign public key so bootc upgrade can verify signatures against it.
## Policy/registries config lives in build_files/files/common/etc/containers/,
## copied in by phase-finalize.sh. Kept above LINTING so it's checked too.
COPY cosign.pub /etc/pki/containers/falcos.pub

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
