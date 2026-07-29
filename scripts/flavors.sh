#!/usr/bin/env bash
# The only reader of ARG FLAVORS in Containerfile.base. Everything that
# needs to know which flavors exist asks this script: the Containerfile
# generator, the CI build matrix, the per-flavor cache tags, the registry
# cleanup, the disk build and the Justfile. Adding or renaming a flavor is
# one edit to ARG FLAVORS and nothing else.
set -euo pipefail
cd "$(dirname "$0")/.."

skeleton=Containerfile.base

# Published images are <prefix>-<flavor>; the buildx registry cache is
# <prefix>-cache, one tag per flavor.
prefix=falcos

# The flavor a fresh installer lays down, and the one its kickstart makes
# the installed system track. Declared here rather than inferred from the
# list: the first entry is a build-order default (the local build, the PR
# build) and carries no claim about which image belongs on a machine
# nobody has inspected.
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
  default             the first flavor, which builds use when none is given
  installer           the flavor a fresh installer ISO lays down
  check <flavor>      succeeds if <flavor> is declared, fails loudly if not
  siblings <flavor>   every flavor except <flavor>
  image [<flavor>]    published image name for a flavor (default: default)
  images              published image name for every flavor
  cache-image         image name of the shared build cache
EOF
}

# ---- read the declared flavors ------------------------------------------
raw="$(sed -n 's/^ARG FLAVORS="\(.*\)"$/\1/p' "$skeleton")"
[ -n "$raw" ] || die "ARG FLAVORS not found in ${skeleton}"

flavors=()
declare -A seen=()
IFS=',' read -ra parts <<< "$raw"
for name in "${parts[@]}"; do
    # Flavor names cannot contain whitespace, so stripping it all also
    # tolerates "desktop, laptop" spacing in the ARG.
    name="${name//[[:space:]]/}"
    [ -n "$name" ] || continue
    # Same shape components.list section headers accept; a name outside it
    # could never be matched by a [flavor] section.
    [[ "$name" =~ ^[a-z][a-z0-9-]*$ ]] \
        || die "invalid flavor name '${name}' in ARG FLAVORS (expected lowercase, digits and dashes)"
    [ -z "${seen[$name]:-}" ] || die "flavor '${name}' is listed twice in ARG FLAVORS"
    seen["$name"]=1
    flavors+=("$name")
done
[ "${#flavors[@]}" -gt 0 ] || die "no flavors found in ARG FLAVORS in ${skeleton}"

require_flavor() {
    local wanted="${1:-}"
    [ -n "$wanted" ] || die "expected a flavor name"
    [ -n "${seen[$wanted]:-}" ] \
        || die "'${wanted}' is not a flavor in ARG FLAVORS in ${skeleton} (have: ${flavors[*]})"
}

# ---- commands ------------------------------------------------------------
case "${1:-}" in
    list)
        printf '%s\n' "${flavors[@]}"
        ;;
    default)
        printf '%s\n' "${flavors[0]}"
        ;;
    installer)
        [ -n "${seen[$installer]:-}" ] \
            || die "the installer flavor '${installer}' is not in ARG FLAVORS in ${skeleton} (have: ${flavors[*]})"
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
        name="${2:-${flavors[0]}}"
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
