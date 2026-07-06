# Build scripts, referenced below without being copied into the final image.
# Built and tagged as its own image in .github/workflows/build.yml, NOT
# declared as a stage here — see Containerfile.ctx for why.

# Base Image
FROM quay.io/fedora/fedora-bootc:44@sha256:418068a16be639037e8584ffc92d3919ea246e1234705b5d3bb21f91b12fd751

### [IM]MUTABLE /opt
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt

### MODIFICATIONS
## Split into layers ordered by how often each part changes, and further
## split within common/core and common/frequent into themed groups (see
## build_files/phase-core.sh / phase-frequent.sh / phase-flavor.sh) — each
## group is its own RUN/layer, with its bind mounts scoped to only the
## scripts (and version-pin file, if any) that group needs. This means a
## change to one group — whether a script edit or a Renovate version bump —
## only busts that group's own build cache and only forces a re-download of
## that group's layer on `bootc upgrade`, not the whole phase.
##
## files/common itself is NOT bind-mounted here even though it applies to
## every group: it's copied wholesale in phase-finalize.sh instead (the last
## layer), since everything in it is consumed at boot/runtime by systemd
## units, not read during any of these scripts' own execution — so editing
## any file under files/common never busts the expensive layers above. The
## two exceptions that genuinely are read mid-build (sb_cert.der, MOK signing;
## 99-hardening, chown/chmod'd) get their own narrow mounts below, right in
## the group that actually needs them.

RUN --mount=type=bind,from=localhost/falcos-ctx,source=/phase-setup.sh,target=/ctx/phase-setup.sh \
    /ctx/phase-setup.sh

## common/core, grouped by theme:

RUN --mount=type=bind,from=localhost/falcos-ctx,source=/phase-core.sh,target=/ctx/phase-core.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/core/000-repos.sh,target=/ctx/common/core/000-repos.sh \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/phase-core.sh 000-repos.sh

RUN --mount=type=bind,from=localhost/falcos-ctx,source=/phase-core.sh,target=/ctx/phase-core.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/versions-core-theming.sh,target=/ctx/versions-core-theming.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/core/010-kde-desktop.sh,target=/ctx/common/core/010-kde-desktop.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/core/020-kde-theming.sh,target=/ctx/common/core/020-kde-theming.sh \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/phase-core.sh 010-kde-desktop.sh 020-kde-theming.sh

RUN --mount=type=bind,from=localhost/falcos-ctx,source=/phase-core.sh,target=/ctx/phase-core.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/core/030-cli-tools.sh,target=/ctx/common/core/030-cli-tools.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/core/040-dev-tools.sh,target=/ctx/common/core/040-dev-tools.sh \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/phase-core.sh 030-cli-tools.sh 040-dev-tools.sh

RUN --mount=type=bind,from=localhost/falcos-ctx,source=/phase-core.sh,target=/ctx/phase-core.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/versions-core-kernel.sh,target=/ctx/versions-core-kernel.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/lib,target=/ctx/lib \
    --mount=type=bind,from=localhost/falcos-ctx,source=/files/common/usr/share/falcos/sb_cert.der,target=/ctx/files/sb_cert.der \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/core/050-bootloader.sh,target=/ctx/common/core/050-bootloader.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/core/060-cachyos-kernel.sh,target=/ctx/common/core/060-cachyos-kernel.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/core/070-hardware.sh,target=/ctx/common/core/070-hardware.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/core/080-xone-dkms.sh,target=/ctx/common/core/080-xone-dkms.sh \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=mok_privkey,target=/run/secrets/mok_privkey,required=false \
    /ctx/phase-core.sh 050-bootloader.sh 060-cachyos-kernel.sh 070-hardware.sh 080-xone-dkms.sh

RUN --mount=type=bind,from=localhost/falcos-ctx,source=/phase-core.sh,target=/ctx/phase-core.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/core/090-multimedia.sh,target=/ctx/common/core/090-multimedia.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/core/100-networking.sh,target=/ctx/common/core/100-networking.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/core/110-virtualization.sh,target=/ctx/common/core/110-virtualization.sh \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/phase-core.sh 090-multimedia.sh 100-networking.sh 110-virtualization.sh

RUN --mount=type=bind,from=localhost/falcos-ctx,source=/phase-core.sh,target=/ctx/phase-core.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/files/common/etc/sudoers.d/99-hardening,target=/ctx/files/99-hardening \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/core/120-security.sh,target=/ctx/common/core/120-security.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/core/130-hardening.sh,target=/ctx/common/core/130-hardening.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/core/140-selinux.sh,target=/ctx/common/core/140-selinux.sh \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/phase-core.sh 120-security.sh 130-hardening.sh 140-selinux.sh

RUN --mount=type=bind,from=localhost/falcos-ctx,source=/phase-core.sh,target=/ctx/phase-core.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/core/150-copr-extras.sh,target=/ctx/common/core/150-copr-extras.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/core/160-greenboot.sh,target=/ctx/common/core/160-greenboot.sh \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/phase-core.sh 150-copr-extras.sh 160-greenboot.sh

## common/frequent, grouped by theme, plus the flavor-specific script last:

RUN --mount=type=bind,from=localhost/falcos-ctx,source=/phase-frequent.sh,target=/ctx/phase-frequent.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/versions-frequent-tools.sh,target=/ctx/versions-frequent-tools.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/frequent/000-pinned-tools.sh,target=/ctx/common/frequent/000-pinned-tools.sh \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/phase-frequent.sh 000-pinned-tools.sh

RUN --mount=type=bind,from=localhost/falcos-ctx,source=/phase-frequent.sh,target=/ctx/phase-frequent.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/versions-frequent-network.sh,target=/ctx/versions-frequent-network.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/frequent/010-vpn.sh,target=/ctx/common/frequent/010-vpn.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/frequent/020-network-audio.sh,target=/ctx/common/frequent/020-network-audio.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/common/frequent/030-browser.sh,target=/ctx/common/frequent/030-browser.sh \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/phase-frequent.sh 010-vpn.sh 020-network-audio.sh 030-browser.sh

# Declared here, immediately before the one step that needs it, rather than
# right after FROM: per containers/buildah#4536, buildah's registry
# --cache-from/--cache-to import breaks for every layer after an ARG when
# local storage isn't persistent across builds — true for every GitHub
# Actions runner. Keeping ARG this low means only this one flavor-specific
# layer loses cache import; phase-setup/phase-core/phase-frequent above are
# unaffected.
ARG FLAVOR=laptop

RUN --mount=type=bind,from=localhost/falcos-ctx,source=/phase-flavor.sh,target=/ctx/phase-flavor.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/versions-frequent-desktop.sh,target=/ctx/versions-frequent-desktop.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/lib,target=/ctx/lib \
    --mount=type=bind,from=localhost/falcos-ctx,source=/${FLAVOR}.sh,target=/ctx/${FLAVOR}.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/files/${FLAVOR},target=/ctx/files/${FLAVOR} \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=mok_privkey,target=/run/secrets/mok_privkey,required=false \
    FLAVOR=${FLAVOR} /ctx/phase-flavor.sh

RUN --mount=type=bind,from=localhost/falcos-ctx,source=/phase-finalize.sh,target=/ctx/phase-finalize.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/enable-services.sh,target=/ctx/enable-services.sh \
    --mount=type=bind,from=localhost/falcos-ctx,source=/files/common,target=/ctx/files/common \
    /ctx/phase-finalize.sh

### SIGNING POLICY
## Bake cosign public key so bootc upgrade can verify signatures against it.
## Policy/registries config lives in build_files/files/common/etc/containers/,
## copied in by phase-finalize.sh. Kept above LINTING so it's checked too.
COPY cosign.pub /etc/pki/containers/falcos.pub

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
