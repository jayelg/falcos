#!/usr/bin/env bash
# Image naming, over the flavor set declared in modules.kdl. Everything
# that needs to know which flavors exist asks this script: the CI build
# matrix, the per-flavor cache tags, the registry cleanup, the disk build
# and the Justfile.
#
# scripts/manifest.sh owns what the flavors *are*; this owns what they are
# called once published. scripts/registry.sh owns where they live.
set -euo pipefail
cd "$(dirname "$0")/.."

# Published images are <prefix>-<flavor>; the buildx registry cache is
# <prefix>-cache, one tag per flavor.
prefix=falcos

# The flavor a fresh installer lays down, and the one its kickstart makes
# the installed system track. Declared here rather than inferred from the
# list: the default flavor is a build-order fact and carries no claim
# about which image belongs on a machine nobody has inspected.
#
# laptop, not desktop, because the desktop flavor ships VFIO kargs that
# bind devices to vfio-pci at boot. On unknown hardware that can hand the
# GPU to a driver nothing is using, which is exactly the situation an
# installer is in. Do not "fix" this to the default flavor.
installer=laptop

die() {
    echo "flavors: $*" >&2
    exit 1
}

usage() {
    cat >&2 <<'EOF'
usage: scripts/flavors.sh <command> [flavor]

All output is one item per line, in declaration order.

  list                every flavor
  default             the flavor marked default in modules.kdl, which
                      builds use when none is given
  pr                  the flavor a pull request builds
  installer           the flavor a fresh installer ISO lays down
  check <flavor>      succeeds if <flavor> is declared, fails loudly if not
  siblings <flavor>   every flavor except <flavor>
  image [<flavor>]    published image name for a flavor (default: default)
  images              published image name for every flavor
  cache-image         image name of the shared build cache
EOF
}

mapfile -t flavors < <(./scripts/manifest.sh flavors)
[ "${#flavors[@]}" -gt 0 ] || die "no flavors declared in modules.kdl"

declare -A seen=()
for name in "${flavors[@]}"; do
    seen["$name"]=1
done

require_flavor() {
    local wanted="${1:-}"
    [ -n "$wanted" ] || die "expected a flavor name"
    [ -n "${seen[$wanted]:-}" ] \
        || die "'${wanted}' is not a flavor in modules.kdl (have: ${flavors[*]})"
}

case "${1:-}" in
    list)
        printf '%s\n' "${flavors[@]}"
        ;;
    default)
        ./scripts/manifest.sh default-flavor
        ;;
    pr)
        ./scripts/manifest.sh pr-flavor
        ;;
    installer)
        [ -n "${seen[$installer]:-}" ] \
            || die "the installer flavor '${installer}' is not in modules.kdl (have: ${flavors[*]})"
        printf '%s\n' "$installer"
        ;;
    check)
        require_flavor "${2:-}"
        ;;
    siblings)
        require_flavor "${2:-}"
        for name in "${flavors[@]}"; do
            [ "$name" = "$2" ] || printf '%s\n' "$name"
        done
        ;;
    image)
        name="${2:-$(./scripts/manifest.sh default-flavor)}"
        require_flavor "$name"
        printf '%s-%s\n' "$prefix" "$name"
        ;;
    images)
        for name in "${flavors[@]}"; do
            printf '%s-%s\n' "$prefix" "$name"
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
