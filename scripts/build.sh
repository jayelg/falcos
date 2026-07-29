#!/usr/bin/env bash
# The single build invocation. `just build` and the build workflow both
# call this, so build args, cache refs and the signing secret cannot drift
# between a local build and CI. Backends differ only in how they reach
# BuildKit:
#
#   buildx    the runner's buildx builder, used by the workflow
#   buildah   podman build; no BuildKit, so no shared cache. Kept while the
#             BuildKit path settles.
#
# Everything else — which Containerfile is built, which build args and
# secret it gets, which cache refs are read and written — is decided here
# once for every caller.
set -euo pipefail
cd "$(dirname "$0")/.."

containerfile=Containerfile.generated

die() {
    echo "build: $*" >&2
    exit 1
}

usage() {
    cat >&2 <<'EOF'
usage: scripts/build.sh [options]

  --flavor <name>     flavor to build (default: scripts/flavors.sh default)
  --kernel <name>     KERNEL build arg (default: unset, the Containerfile
                      decides, which is how the kernel-freshness fallback
                      switches the whole pipeline to the stock kernel)
  --tag <ref>         tag the result; repeatable
  --backend <name>    buildx or buildah (default: $BUILD_BACKEND, else buildah)
  --oci-output <path> write an OCI archive here instead of loading the image
  --cache-to          export the layer cache to the registry cache repo
  --no-cache-from     do not import the registry layer cache

Environment:
  TAGS                newline-separated tags, as the metadata action emits
  LABELS              newline-separated OCI labels, same shape
  IMAGE_VERSION       stamped into the image (default: today, UTC)
  IMAGE_REGISTRY      registry holding the layer cache (default: derived
                      from the origin remote)
  MOK_KEY_PATH        Secure Boot signing key, mounted as a build secret
EOF
}

# ---- arguments -----------------------------------------------------------
backend="${BUILD_BACKEND:-buildah}"
flavor=""
kernel=""
oci_output=""
cache_from=1
cache_to=0
tags=()
labels=()

need_value() {
    [ "$2" -ge 2 ] || die "$1 needs a value"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --flavor)
            need_value "$1" "$#"
            flavor="$2"
            shift 2
            ;;
        --kernel)
            need_value "$1" "$#"
            kernel="$2"
            shift 2
            ;;
        --tag)
            need_value "$1" "$#"
            tags+=("$2")
            shift 2
            ;;
        --backend)
            need_value "$1" "$#"
            backend="$2"
            shift 2
            ;;
        --oci-output)
            need_value "$1" "$#"
            oci_output="$2"
            shift 2
            ;;
        --cache-to)
            cache_to=1
            shift
            ;;
        --no-cache-from)
            cache_from=0
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            usage
            die "unknown argument '$1'"
            ;;
    esac
done

case "$backend" in
    buildx | buildah) ;;
    *) die "unknown backend '${backend}' (buildx or buildah)" ;;
esac

# ---- resolved build inputs -----------------------------------------------
# scripts/flavors.sh is the only reader of ARG FLAVORS; asking it for the
# default and validating against it is what keeps a typo out of a 50 minute
# build.
flavor="${flavor:-$(./scripts/flavors.sh default)}"
./scripts/flavors.sh check "$flavor"

image_version="${IMAGE_VERSION:-$(date -u +%Y%m%d)}"

while IFS= read -r line; do
    if [ -n "$line" ]; then tags+=("$line"); fi
done <<< "${TAGS:-}"
[ "${#tags[@]}" -gt 0 ] || tags=("${IMAGE_NAME:-falcos}:${DEFAULT_TAG:-latest}")

while IFS= read -r line; do
    if [ -n "$line" ]; then labels+=("$line"); fi
done <<< "${LABELS:-}"

# An empty MOK_KEY_PATH means "no signing key", which is a supported build.
# A non-empty one that does not exist is a typo, and silently shipping
# unsigned kernel modules is the expensive way to find out.
mok_key="${MOK_KEY_PATH:-}"
[ -z "$mok_key" ] || [ -f "$mok_key" ] \
    || die "MOK_KEY_PATH is set to '${mok_key}' but that file does not exist"

# ---- registry layer cache ------------------------------------------------
# One cache repo, one tag per flavor (a cache export is a single manifest
# per ref, so flavors sharing a tag would clobber each other). Each build
# reads its own tag first, then every sibling: those still serve the
# flavor-agnostic layers, which are most of the build.
cache_repo() {
    local registry="${IMAGE_REGISTRY:-}"
    if [ -z "$registry" ]; then
        # Derived from the remote so a fork's local build reads the fork's
        # own CI cache with no configuration.
        local url owner
        url="$(git config --get remote.origin.url 2> /dev/null || true)"
        owner="$(printf '%s\n' "$url" \
            | sed -n 's#^\(git@github\.com:\|ssh://git@github\.com/\|https://github\.com/\)\([^/]*\)/.*#\2#p')"
        [ -n "$owner" ] || return 1
        registry="ghcr.io/${owner,,}"
    fi
    printf '%s/%s\n' "${registry,,}" "$(./scripts/flavors.sh cache-image)"
}

cache_import_refs=()
cache_export_ref=""
if [ "$cache_from" = 1 ] || [ "$cache_to" = 1 ]; then
    if repo="$(cache_repo)"; then
        if [ "$cache_from" = 1 ]; then
            cache_import_refs+=("${repo}:${flavor}")
            while IFS= read -r sibling; do
                cache_import_refs+=("${repo}:${sibling}")
            done < <(./scripts/flavors.sh siblings "$flavor")
        fi
        [ "$cache_to" = 0 ] || cache_export_ref="${repo}:${flavor},mode=max"
    else
        [ "$cache_to" = 0 ] \
            || die "--cache-to needs IMAGE_REGISTRY set (no github origin remote to derive it from)"
        echo "build: no github origin remote, skipping the registry cache" >&2
    fi
fi

# ---- the Containerfile the build actually uses ---------------------------
# Regenerated here rather than by each caller: a build against a stale
# Containerfile.generated is a build of the wrong image.
./scripts/gen-containerfile.sh

build_args=(
    "FLAVOR=${flavor}"
    "IMAGE_VERSION=${image_version}"
)
[ -z "$kernel" ] || build_args+=("KERNEL=${kernel}")

echo "build: ${backend} flavor=${flavor} version=${image_version}${kernel:+ kernel=${kernel}}"
echo "build: tags ${tags[*]}"
[ "${#cache_import_refs[@]}" -eq 0 ] \
    || echo "build: importing cache from ${cache_import_refs[*]}"
[ -z "$cache_export_ref" ] || echo "build: exporting cache to ${cache_export_ref}"

# ---- backends ------------------------------------------------------------
build_buildx() {
    local args=(build --file "$containerfile")
    local arg tag label ref

    for arg in "${build_args[@]}"; do args+=(--build-arg "$arg"); done
    for tag in "${tags[@]}"; do args+=(--tag "$tag"); done
    for label in "${labels[@]}"; do args+=(--label "$label"); done
    for ref in "${cache_import_refs[@]}"; do
        args+=(--cache-from "type=registry,ref=${ref}")
    done
    [ -z "$cache_export_ref" ] \
        || args+=(--cache-to "type=registry,ref=${cache_export_ref}")
    [ -z "$mok_key" ] \
        || args+=(--secret "id=mok_privkey,src=${mok_key}")
    # An attestation index is not the shape bootc and cosign expect, so the
    # output stays a single image manifest.
    args+=(--provenance=false)
    [ -z "$oci_output" ] \
        || args+=(--output "type=oci,dest=${oci_output}")

    docker buildx "${args[@]}" .
}

# No BuildKit, so no --mount cache scoping and no shared cache: buildah
# keys the RUN cache on the whole ctx stage and rebuilds every layer after
# any change under components/, lib/ or build-phases/.
build_buildah() {
    local args=(build --file "$containerfile")
    local arg tag label

    for arg in "${build_args[@]}"; do args+=(--build-arg "$arg"); done
    for tag in "${tags[@]}"; do args+=(--tag "$tag"); done
    for label in "${labels[@]}"; do args+=(--label "$label"); done
    [ -z "$mok_key" ] \
        || args+=(--secret "id=mok_privkey,src=${mok_key}")
    [ -z "$oci_output" ] \
        || die "the buildah backend cannot write an OCI archive"
    [ "${#cache_import_refs[@]}" -eq 0 ] \
        || echo "build: buildah ignores the registry layer cache" >&2
    [ -z "$cache_export_ref" ] \
        || die "buildah cannot export a BuildKit layer cache"

    podman "${args[@]}" --pull=newer .
}

# Validated above, so the name is one of the functions defined here.
"build_${backend}"
