#!/usr/bin/env bash
# The single build invocation. `just build` and the build workflow both
# call this, so build args, cache refs and build secrets cannot drift
# between a local build and CI. Backends differ only in how they reach
# BuildKit:
#
#   buildkit  buildkitd in a podman container driven by buildctl, the
#             local default: the same builder CI uses, so a local build
#             resolves the same cache keys
#   buildx    the runner's buildx builder, used by the workflow
#   buildah   podman build. Not BuildKit: the RUN cache keys on the whole
#             ctx stage instead of the mounted files, nothing is shared
#             with CI, and the Containerfile's syntax directive is ignored.
#             It is the fallback for a host where a privileged buildkitd
#             container cannot run, kept permanently rather than during a
#             migration, and it fails loudly on anything it cannot do
#             rather than quietly producing a different image.
#
# Everything else — which Containerfile is built, which build args and
# secrets it gets, which cache refs are read and written — is decided here
# once for every caller.
set -euo pipefail
cd "$(dirname "$0")/.."

# The checkout's default image, from image.kdl. The local daemon and its
# cache volume are named after it so one checkout's build state is its
# own, and so nothing here spells a name out. One daemon serves every
# image: its state is a layer cache, which is shared, not per image.
default_image="$(./scripts/manifest.sh default-image)"

# renovate: datasource=docker depName=docker.io/moby/buildkit
buildkit_image="docker.io/moby/buildkit:v0.31.2"
buildkit_container="${default_image}-buildkitd"
buildkit_volume="${default_image}-buildkit"
buildkit_label="${default_image}.buildkitd"
# Paths inside that container, not on the host
buildkit_context=/build
buildkit_secret_dir=/run/secrets

die() {
	echo "build: $*" >&2
	exit 1
}

usage() {
	cat >&2 <<'EOF'
usage: scripts/build.sh [options]

  --target <image/flavor>
                      what to build, e.g. falcos/desktop; the flavor half
                      is `none` for the ungated set, which publishes
                      unsuffixed (default: scripts/targets.sh default)
  --kernel <name>     KERNEL build arg (default: unset, the Containerfile
                      decides, which is how the kernel-freshness fallback
                      switches the whole pipeline to the stock kernel)
  --tag <ref>         tag the result; repeatable
  --secret <id>=<path>
                      mount <path> as the build secret <id>, one of the
                      IDs `scripts/manifest.sh secrets` lists; repeatable
  --backend <name>    buildkit, buildx or buildah (default: $BUILD_BACKEND,
                      else buildkit)
  --oci-output <path> write an OCI archive here instead of loading the image
  --cache-to          export the layer cache to the registry cache repo
  --no-cache-from     do not import the registry layer cache
  --reset             remove the BuildKit daemon and its cache volume,
                      then exit; the next build starts cold

Environment:
  TAGS                newline-separated tags, as the metadata action emits
  LABELS              newline-separated OCI labels, same shape
  IMAGE_VERSION       stamped into the image (default: today, UTC)
  IMAGE_REGISTRY      registry holding the layer cache (default: derived
                      from the origin remote)
  MOK_KEY_PATH        shorthand for `--secret mok_privkey=<path>`, the one
                      secret a local build is likely to have
EOF
}

# ---- arguments -----------------------------------------------------------
backend="${BUILD_BACKEND:-buildkit}"
target=""
kernel=""
oci_output=""
cache_from=1
cache_to=0
reset=0
tags=()
labels=()
secrets=()

need_value() {
	[ "$2" -ge 2 ] || die "$1 needs a value"
}

while [ $# -gt 0 ]; do
	case "$1" in
	--target)
		need_value "$1" "$#"
		target="$2"
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
	--secret)
		need_value "$1" "$#"
		secrets+=("$2")
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
	--reset)
		reset=1
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
buildkit | buildx | buildah) ;;
*) die "unknown backend '${backend}' (buildkit, buildx or buildah)" ;;
esac

# The daemon and its volume are this script's to create, so they are also
# its to remove: their names live here and nowhere else.
if [ "$reset" = 1 ]; then
	podman rm --force "$buildkit_container" >/dev/null 2>&1 || true
	podman volume rm --force "$buildkit_volume" >/dev/null 2>&1 || true
	echo "build: removed the buildkit daemon and its cache volume"
	exit 0
fi

# ---- resolved build inputs -----------------------------------------------
# scripts/targets.sh derives both from what image.kdl declares; asking it
# for the default and validating against it is what keeps a typo out of a
# 50 minute build.
target="${target:-$(./scripts/targets.sh default)}"
./scripts/targets.sh check "$target"

# The two halves. Which image decides what is built and which generated
# Containerfile builds it; the flavor decides what is gated in.
image="${target%%/*}"
flavor="${target#*/}"

# One generated Containerfile per image, named for the image. Derived
# rather than fixed: images build on different bases, so which file this
# build uses follows from which image is being built.
containerfile="containerfiles/${image}.generated"

# `none` names the ungated build for a cache tag and a matrix entry, but
# inside the build it is simply no flavor: FLAVOR is empty, so every
# flavor gate skips and the image is the shared layers.
flavor_arg="$flavor"
[ "$flavor" != none ] || flavor_arg=""

image_version="${IMAGE_VERSION:-$(date -u +%Y%m%d)}"

while IFS= read -r line; do
	if [ -n "$line" ]; then tags+=("$line"); fi
done <<<"${TAGS:-}"
[ "${#tags[@]}" -gt 0 ] ||
	tags=("${IMAGE_NAME:-$(./scripts/targets.sh image "$target")}:${DEFAULT_TAG:-latest}")

while IFS= read -r line; do
	if [ -n "$line" ]; then labels+=("$line"); fi
done <<<"${LABELS:-}"

# Build secrets. Every module declares the IDs it wants, the workflow
# derives them from the manifests and passes one --secret per ID, and
# nothing here knows what any of them is for: this script mounts what it
# is given. Every secret is `required=false` in the Containerfile, so a
# build with none of them is a supported build that skips what they
# enable.
#
# MOK_KEY_PATH is shorthand for the one a local build is likely to have,
# since a human exporting an env var should not have to know the manifest
# ID. Both spellings at once is a typo, not a merge.
if [ -n "${MOK_KEY_PATH:-}" ]; then
	for pair in "${secrets[@]}"; do
		[ "${pair%%=*}" != "mok_privkey" ] ||
			die "MOK_KEY_PATH and --secret mok_privkey= both set; use one"
	done
	secrets+=("mok_privkey=${MOK_KEY_PATH}")
fi

# A declared secret whose file is missing is a typo, and silently
# shipping unsigned kernel modules is the expensive way to find out.
for pair in "${secrets[@]}"; do
	case "$pair" in
	?*=?*) ;;
	*) die "--secret takes <id>=<path>, got '${pair}'" ;;
	esac
	[ -f "${pair#*=}" ] ||
		die "secret '${pair%%=*}' points at '${pair#*=}', which does not exist"
done

# ---- registry layer cache ------------------------------------------------
# One cache repo, one tag per target (a cache export is a single manifest
# per ref, so targets sharing a tag would clobber each other). Each build
# reads its own tag first, then every sibling: those still serve the
# flavor-agnostic layers, which are most of the build. The ungated build
# is the best sibling any flavor has, since it is nothing but those.
#
# The namespace comes from scripts/registry.sh, so a fork's local build
# reads the fork's own CI cache with no configuration. It fails when there
# is nothing to derive one from, which is fatal for an export and only a
# missed cache for an import.
cache_import_refs=()
cache_export_ref=""
if [ "$cache_from" = 1 ] || [ "$cache_to" = 1 ]; then
	if repo="$(./scripts/registry.sh ref "$(./scripts/targets.sh cache-image)")"; then
		# One tag per target, spelled as the published image name: a tag
		# cannot hold the slash a target is written with, and the
		# published name is already unique across images.
		tag="$(./scripts/targets.sh image "$target")"
		if [ "$cache_from" = 1 ]; then
			cache_import_refs+=("${repo}:${tag}")
			while IFS= read -r sibling; do
				cache_import_refs+=("${repo}:$(./scripts/targets.sh image "$sibling")")
			done < <(./scripts/targets.sh siblings "$target")
		fi
		[ "$cache_to" = 0 ] || cache_export_ref="${repo}:${tag},mode=max"
	else
		[ "$cache_to" = 0 ] || die "--cache-to needs a registry namespace"
		echo "build: skipping the registry layer cache" >&2
	fi
fi

# ---- the Containerfile the build actually uses ---------------------------
# Regenerated here rather than by each caller: a build against a stale
# generated Containerfile is a build of the wrong image.
./scripts/gen-containerfile.sh

# The contract file paths the validation layer asserts, and the verify
# diagnostics it accepts on named units. Resolved here, from the
# manifests, because the host is the only side that knows which modules
# this target enables; the image would have to be told anyway. Space
# separated: every path is absolute, every exception is one
# <class>|<unit> token, and none of them contains a space.
#
# The registry namespace comes from the same place the cache refs do, so
# the signature policy baked into the image is scoped to wherever this
# checkout publishes. Empty when there is nothing to derive one from,
# which the finalize phase reports rather than guessing at a namespace.
build_args=(
	"FLAVOR=${flavor_arg}"
	"IMAGE_VERSION=${image_version}"
	"IMAGE_REGISTRY=$(./scripts/registry.sh namespace 2>/dev/null || true)"
	"CONTRACT_FILES=$(./scripts/manifest.sh contract-files "$target" | tr '\n' ' ')"
	"VERIFY_EXCEPTIONS=$(./scripts/manifest.sh verify-exceptions "$target" | tr '\n' ' ')"
)
[ -z "$kernel" ] || build_args+=("KERNEL=${kernel}")

echo "build: ${backend} target=${target} version=${image_version}${kernel:+ kernel=${kernel}}"
echo "build: tags ${tags[*]}"
[ "${#cache_import_refs[@]}" -eq 0 ] ||
	echo "build: importing cache from ${cache_import_refs[*]}"
[ -z "$cache_export_ref" ] || echo "build: exporting cache to ${cache_export_ref}"

# ---- backends ------------------------------------------------------------
# buildkitd in a podman container, the same daemon CI drives through
# buildx. Its state — the layer cache and every RUN --mount=type=cache —
# lives in a named volume, so it survives the container and a rebuild
# after a one line change re-runs one layer instead of forty.
#
# Privileged because buildkitd mounts overlayfs for its snapshotter. Under
# rootless podman that stays inside the user namespace: root in the
# container is the invoking user outside it, and nothing on the host is
# writable that the user could not already write.
buildkitd_ensure() {
	local run_args=(
		--detach
		--name "$buildkit_container"
		--privileged
		--security-opt label=disable
		--volume "${buildkit_volume}:/var/lib/buildkit"
		--volume "${PWD}:${buildkit_context}:ro"
	)
	local pair
	for pair in "${secrets[@]}"; do
		run_args+=(--volume "${pair#*=}:${buildkit_secret_dir}/${pair%%=*}:ro")
	done

	# The daemon outlives a build but its mounts are fixed at start, so
	# the config it was started with is stamped on it and a changed one
	# recreates it. The cache is in the volume, so that costs nothing.
	local want have
	want="$(printf '%s\n' "$buildkit_image" "${run_args[@]}" | sha256sum | cut -d' ' -f1)"
	have="$(podman inspect --format \
		"{{index .Config.Labels \"${buildkit_label}\"}} {{.State.Running}}" \
		"$buildkit_container" 2>/dev/null || true)"
	[ "$have" = "${want} true" ] && return 0

	podman rm --force "$buildkit_container" >/dev/null 2>&1 || true
	podman run "${run_args[@]}" --label "${buildkit_label}=${want}" \
		"$buildkit_image" >/dev/null

	for _ in $(seq 30); do
		if podman exec "$buildkit_container" buildctl debug workers >/dev/null 2>&1; then
			return 0
		fi
		sleep 1
	done
	podman logs "$buildkit_container" >&2 || true
	die "buildkitd did not come up"
}

# podman resolves a bare name against the search registries, so a plain
# `falcos:latest` loaded from a tarball would land as docker.io/library.
# podman build spells the same tag localhost/falcos:latest; match it, so
# the disk image recipes find what a build just produced.
local_ref() {
	local first="${1%%/*}"
	if [ "$first" != "$1" ]; then
		case "$first" in
		*.* | *:* | localhost)
			printf '%s\n' "$1"
			return
			;;
		esac
	fi
	printf 'localhost/%s\n' "$1"
}

build_buildkit() {
	buildkitd_ensure

	local args=(
		build
		--frontend dockerfile.v0
		--local "context=${buildkit_context}"
		--local "dockerfile=${buildkit_context}"
		--opt "filename=${containerfile}"
	)
	local arg label ref tag first pair

	for arg in "${build_args[@]}"; do args+=(--opt "build-arg:${arg}"); done
	for label in "${labels[@]}"; do args+=(--opt "label:${label}"); done
	for ref in "${cache_import_refs[@]}"; do
		args+=(--import-cache "type=registry,ref=${ref}")
	done
	[ -z "$cache_export_ref" ] ||
		args+=(--export-cache "type=registry,ref=${cache_export_ref}")
	# src is the path inside the daemon container, where buildkitd_ensure
	# mounted it, not the host path.
	for pair in "${secrets[@]}"; do
		args+=(--secret "id=${pair%%=*},src=${buildkit_secret_dir}/${pair%%=*}")
	done

	# buildctl writes the exported image to stdout when it is given no
	# destination, so the tarball streams straight into podman storage
	# rather than being written out and read back.
	if [ -n "$oci_output" ]; then
		podman exec "$buildkit_container" buildctl "${args[@]}" \
			--output "type=oci,name=${tags[0]}" >"$oci_output"
		return
	fi

	first="$(local_ref "${tags[0]}")"
	podman exec "$buildkit_container" buildctl "${args[@]}" \
		--output "type=docker,name=${first}" | podman load --quiet
	for tag in "${tags[@]:1}"; do
		podman tag "$first" "$(local_ref "$tag")"
	done
}

build_buildx() {
	local args=(build --file "$containerfile")
	local arg tag label ref pair

	for arg in "${build_args[@]}"; do args+=(--build-arg "$arg"); done
	for tag in "${tags[@]}"; do args+=(--tag "$tag"); done
	for label in "${labels[@]}"; do args+=(--label "$label"); done
	for ref in "${cache_import_refs[@]}"; do
		args+=(--cache-from "type=registry,ref=${ref}")
	done
	[ -z "$cache_export_ref" ] ||
		args+=(--cache-to "type=registry,ref=${cache_export_ref}")
	for pair in "${secrets[@]}"; do
		args+=(--secret "id=${pair%%=*},src=${pair#*=}")
	done
	# An attestation index is not the shape bootc and cosign expect, so the
	# output stays a single image manifest.
	args+=(--provenance=false)
	[ -z "$oci_output" ] ||
		args+=(--output "type=oci,dest=${oci_output}")

	docker buildx "${args[@]}" .
}

# No BuildKit, so no --mount cache scoping and no shared cache: buildah
# keys the RUN cache on the whole ctx stage and rebuilds every layer after
# any change under modules/, lib/ or build-phases/.
build_buildah() {
	local args=(build --file "$containerfile")
	local arg tag label pair

	for arg in "${build_args[@]}"; do args+=(--build-arg "$arg"); done
	for tag in "${tags[@]}"; do args+=(--tag "$tag"); done
	for label in "${labels[@]}"; do args+=(--label "$label"); done
	for pair in "${secrets[@]}"; do
		args+=(--secret "id=${pair%%=*},src=${pair#*=}")
	done
	[ -z "$oci_output" ] ||
		die "the buildah backend cannot write an OCI archive"
	[ "${#cache_import_refs[@]}" -eq 0 ] ||
		echo "build: buildah ignores the registry layer cache" >&2
	[ -z "$cache_export_ref" ] ||
		die "buildah cannot export a BuildKit layer cache"

	podman "${args[@]}" --pull=newer .
}

# Validated above, so the name is one of the functions defined here.
"build_${backend}"
