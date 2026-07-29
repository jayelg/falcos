#!/usr/bin/env bash
# Renders the installer ISO's bootc-image-builder config from
# disk_config/iso.template.toml, filling in the image the installed system
# is switched to at the end of the install.
#
# It has to be baked in: bootc-image-builder parses a static TOML file and
# offers no flag for that reference on anaconda-iso, the way --rootfs and
# --use-librepo can be passed as arguments. Rendering it here rather than
# committing the result is what keeps the reference derived: a fork's ISO
# installs the fork's image, and the flavor is the one declaration in
# scripts/flavors.sh rather than a string in a config file.
#
# Prints the absolute path it wrote, so a caller can hand it straight to
# bootc-image-builder; everything else goes to stderr. Absolute because
# the path reaches podman as a `--volume` source, and podman reads a bare
# relative one as a volume name rather than a path, which fails with
# "names must match" instead of anything about mounts.
set -euo pipefail
cd "$(dirname "$0")/.."

template=disk_config/iso.template.toml
out=build/iso.generated.toml

die() {
    echo "render-iso-config: $*" >&2
    exit 1
}

usage() {
    cat >&2 <<'EOF'
usage: scripts/render-iso-config.sh [options]

  --flavor <name>   flavor the ISO installs (default:
                    scripts/flavors.sh installer)
  --tag <tag>       tag it tracks (default: $DEFAULT_TAG, else latest)

Environment:
  IMAGE_REGISTRY    registry namespace, as scripts/registry.sh reads it
EOF
}

flavor=""
tag="${DEFAULT_TAG:-latest}"

while [ $# -gt 0 ]; do
    case "$1" in
        --flavor)
            [ "$#" -ge 2 ] || die "--flavor needs a value"
            flavor="$2"
            shift 2
            ;;
        --tag)
            [ "$#" -ge 2 ] || die "--tag needs a value"
            tag="$2"
            shift 2
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

# The default is the declared installer flavor, never the flavor list's
# default: that one is a build-order fact and says nothing about which
# image belongs on a machine nobody has inspected.
flavor="${flavor:-$(./scripts/flavors.sh installer)}"
./scripts/flavors.sh check "$flavor"

IMAGE_REF="$(./scripts/registry.sh ref "$(./scripts/flavors.sh image "$flavor")"):${tag}"
export IMAGE_REF

command -v envsubst > /dev/null 2>&1 \
    || die "envsubst not found; install gettext-envsubst (Fedora) or gettext-base (Debian)"

mkdir -p "$(dirname "$out")"
{
    echo '# GENERATED FILE, do not edit. Produced by scripts/render-iso-config.sh'
    echo '# from disk_config/iso.template.toml.'
    # Allowlisted, never bare: the kickstart body is shell, and a bare
    # envsubst would silently eat the $1 and $HOME a %post script may
    # well contain.
    # shellcheck disable=SC2016  # the allowlist is a literal name, not an expansion
    envsubst '${IMAGE_REF}' < "$template"
} > "$out"

# A substitution that quietly did nothing ships `bootc switch ${IMAGE_REF}`
# verbatim, which then fails during installation on someone's machine
# instead of here. Nothing legitimately reaches the rendered file with a
# ${ left in it, so any survivor is that bug.
# shellcheck disable=SC2016  # a literal pattern, not an expansion
if grep -n '\${' "$out" >&2; then
    die "unsubstituted \${...} above in ${out}; the template may only use \${IMAGE_REF}"
fi

echo "render-iso-config: wrote ${out} (${IMAGE_REF})" >&2
printf '%s\n' "${PWD}/${out}"
