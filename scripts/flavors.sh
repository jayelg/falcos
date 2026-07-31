#!/usr/bin/env bash
# Image naming, over the flavor set declared in image.kdl. Everything
# that needs to know which flavors exist asks this script: the CI build
# matrix, the per-flavor cache tags, the registry cleanup, the disk build
# and the Justfile.
#
# scripts/manifest.sh owns what the flavors *are*; this owns what they are
# called once published. scripts/registry.sh owns where they live.
set -euo pipefail
cd "$(dirname "$0")/.."

# A *flavor* is a declared image variant. A *target* is something the
# matrix builds, which is every flavor plus the ungated set. The ungated
# set is spelled `none`, because a cache tag and a matrix entry both need
# a name, and it publishes unsuffixed.
#
# It needs no declaration: it is the layers above ARG FLAVOR, which exist
# whether or not any flavor does. That is also why it is not a flavor —
# a flavor whose only property is having no modules would be a
# hand-maintained alias for something the build already produces.
none=none

# Published images are <prefix> for the ungated build and <prefix>-<flavor>
# for a flavor; the buildx registry cache is <prefix>-cache, one tag per
# target.
prefix=falcos

die() {
    echo "flavors: $*" >&2
    exit 1
}

usage() {
    cat >&2 <<'EOF'
usage: scripts/flavors.sh <command> [flavor]

All output is one item per line, in declaration order.

  list                every declared flavor
  targets             every build target: the ungated `none`, then flavors
  default             the flavor marked default in image.kdl, which
                      builds use when none is given
  pr                  the flavor a pull request builds
  check <target>      succeeds if <target> is buildable, fails loudly if not
  siblings <target>   every target except <target>
  image [<target>]    published image name (default: the default flavor)
  images              published image name for every target
  cache-image         image name of the shared build cache
EOF
}

mapfile -t flavors < <(./scripts/manifest.sh flavors)
mapfile -t targets < <(./scripts/manifest.sh targets)

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

# falcos for the ungated build, falcos-<flavor> for a flavor. Naming is a
# hierarchy: the project, then device variants suffixed.
image_name() {
    if [ "$1" = "$none" ]; then
        printf '%s\n' "$prefix"
    else
        printf '%s-%s\n' "$prefix" "$1"
    fi
}

case "${1:-}" in
    list)
        [ "${#flavors[@]}" -eq 0 ] || printf '%s\n' "${flavors[@]}"
        ;;
    targets)
        printf '%s\n' "${targets[@]}"
        ;;
    default)
        ./scripts/manifest.sh default-flavor
        ;;
    pr)
        ./scripts/manifest.sh pr-flavor
        ;;
    check)
        require_target "${2:-}"
        ;;
    siblings)
        require_target "${2:-}"
        for name in "${targets[@]}"; do
            [ "$name" = "$2" ] || printf '%s\n' "$name"
        done
        ;;
    image)
        name="${2:-$(./scripts/manifest.sh default-flavor)}"
        require_target "$name"
        image_name "$name"
        ;;
    images)
        for name in "${targets[@]}"; do
            image_name "$name"
        done
        ;;
    cache-image)
        printf '%s-cache\n' "$prefix"
        ;;
    *)
        usage
        exit 1
        ;;
esac
