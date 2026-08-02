#!/usr/bin/env bash
# Image naming, over the build targets the image files declare. Everything
# that needs to know what can be built asks this script: the CI build
# matrix, the per-target cache tags, the registry cleanup, the disk build
# and the Justfile.
#
# scripts/manifest.sh owns what the targets *are*; this owns what they are
# called once published. scripts/registry.sh owns where they live.
set -euo pipefail
cd "$(dirname "$0")/.."

# A *target* is an image and a flavor of it, spelled `<image>/<flavor>`,
# and it is what the matrix builds. The ungated set is spelled
# `<image>/none`, because a cache tag and a matrix entry both need a name,
# and it publishes unsuffixed.
#
# It needs no declaration: it is the layers above ARG FLAVOR, which exist
# whether or not any flavor does. That is also why it is not a flavor —
# a flavor whose only property is having no modules would be a
# hand-maintained alias for something the build already produces.
#
# Targets are qualified by image because a flavor name only means anything
# inside the image that declares it, and two images may well declare the
# same one. Nothing here takes a bare flavor or a bare image: half a target
# is not a target, and guessing which half was meant is how a build of the
# wrong thing starts.
none=none

die() {
    echo "targets: $*" >&2
    exit 1
}

usage() {
    cat >&2 <<'EOF'
usage: scripts/targets.sh <command> [target]

All output is one item per line, in declaration order. A target is
<image>/<flavor>, with <image>/none for the ungated build.

  targets             every build target
  default             what a build with no target named builds
  pr                  the target a pull request builds
  ungated             the default image's ungated target, which is what
                      the installer ISO and the disk builds lay down
  check <target>      succeeds if <target> is buildable, fails loudly if not
  siblings <target>   every other target of the same image, which is every
                      target whose layers are worth importing as cache
  image [<target>]    published image name (default: the default target)
  images              published image name for every target
  cache-image         image name of the shared build cache
EOF
}

mapfile -t targets < <(./scripts/manifest.sh targets)
[ "${#targets[@]}" -gt 0 ] || die "nothing is buildable; no image is declared"

declare -A buildable=()
for name in "${targets[@]}"; do
    buildable["$name"]=1
done

require_target() {
    local wanted="${1:-}"
    [ -n "$wanted" ] || die "expected a target name"
    [ -n "${buildable[$wanted]:-}" ] \
        || die "'${wanted}' is not a build target (have: ${targets[*]})"
}

# The image's own name for its ungated build, <image>-<flavor> for a
# flavor. Naming is a hierarchy: the image, then device variants suffixed.
image_name() {
    local image="${1%%/*}" flavor="${1#*/}"
    if [ "$flavor" = "$none" ]; then
        printf '%s\n' "$image"
    else
        printf '%s-%s\n' "$image" "$flavor"
    fi
}

case "${1:-}" in
    targets)
        printf '%s\n' "${targets[@]}"
        ;;
    default)
        ./scripts/manifest.sh default-target
        ;;
    pr)
        ./scripts/manifest.sh pr-target
        ;;
    ungated)
        printf '%s/%s\n' "$(./scripts/manifest.sh default-image)" "$none"
        ;;
    check)
        require_target "${2:-}"
        ;;
    siblings)
        require_target "${2:-}"
        for name in "${targets[@]}"; do
            [ "$name" = "$2" ] && continue
            # Same image only. A different image builds on its own base, so
            # its layers share nothing with this one and importing its
            # cache is a download that cannot hit.
            [ "${name%%/*}" = "${2%%/*}" ] || continue
            printf '%s\n' "$name"
        done
        ;;
    image)
        name="${2:-$(./scripts/manifest.sh default-target)}"
        require_target "$name"
        image_name "$name"
        ;;
    images)
        for name in "${targets[@]}"; do
            image_name "$name"
        done
        ;;
    cache-image)
        # One cache repository for the checkout rather than one per image:
        # the tags in it are the published image names, which are already
        # unique across images.
        printf '%s-cache\n' "$(./scripts/manifest.sh default-image)"
        ;;
    *)
        usage
        exit 1
        ;;
esac
