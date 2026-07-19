# CI builds with BuildKit (docker/build-push-action); local `just build`
# uses buildah with coarser caching (see Justfile). The component section
# between the BEGIN/END COMPONENTS markers is generated from
# COMPONENTS.list by scripts/gen-containerfile.sh (`just generate`).
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

### Build arguments
# laptop (default) or desktop: selects the files/ overlay and flavors/ script.
ARG FLAVOR=laptop
# cachyos (default) or stock. stock keeps the Fedora base kernel and is
# the temporary fallback flipped by .github/workflows/kernel-freshness.yml
# (which seds this exact line) when the CachyOS COPR goes stale; see
# build_files/lib/kernel-helpers.sh.
ARG KERNEL=cachyos
# CI passes the YYYYMMDD build date; local builds get it from `just build`
ARG IMAGE_VERSION=dev

RUN --mount=type=bind,from=ctx,source=/common/phase-setup.sh,target=/ctx/common/phase-setup.sh \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    /ctx/common/phase-setup.sh

## Components: one RUN layer each for independent BuildKit caching, run
## through lib/run-component.sh (repo file, version pins, files overlay).

# ---- BEGIN COMPONENTS (generated at build time from COMPONENTS.list; see scripts/gen-containerfile.sh) ----
#
# Intentionally empty in git. This committed file is the build skeleton:
# at build time (`just build` locally, the Sync step in CI) one RUN layer
# per COMPONENTS.list entry is spliced in here and the result is written
# to Containerfile.generated, which is what actually builds. To change
# what the image contains, edit COMPONENTS.list, not this file.
#
# ---- END COMPONENTS ----

RUN --mount=type=bind,from=ctx,source=/common/phase-flavor.sh,target=/ctx/common/phase-flavor.sh \
    --mount=type=bind,from=ctx,source=/lib/brand-helpers.sh,target=/ctx/lib/brand-helpers.sh \
    --mount=type=bind,from=ctx,source=/flavors/${FLAVOR}.sh,target=/ctx/flavors/${FLAVOR}.sh \
    --mount=type=bind,from=ctx,source=/files/${FLAVOR},target=/ctx/files/${FLAVOR} \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    FLAVOR=${FLAVOR} IMAGE_VERSION=${IMAGE_VERSION} /ctx/common/phase-flavor.sh

RUN --mount=type=bind,from=ctx,source=/common/phase-finalize.sh,target=/ctx/common/phase-finalize.sh \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=bind,from=ctx,source=/files/common,target=/ctx/files/common \
    /ctx/common/phase-finalize.sh

### SIGNING POLICY
## Bake cosign public key so bootc upgrade can verify signatures against it.
## Policy/registries config lives in build_files/files/common/etc/containers/,
## copied in by phase-finalize.sh. Kept above LINTING so it's checked too.
COPY cosign.pub /etc/pki/containers/falcos.pub

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
