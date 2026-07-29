#!/usr/bin/env bash
# The only place the registry namespace is derived. Anything that needs a
# published reference asks this script (the build's layer cache refs, the
# image the installer ISO lays down), so a fork's references follow the
# fork's own remote with no configuration and there is no second copy of
# the remote parsing to drift.
#
# scripts/flavors.sh owns image *names* (falcos-<flavor>); this owns where
# they live.
set -euo pipefail
cd "$(dirname "$0")/.."

die() {
    echo "registry: $*" >&2
    exit 1
}

usage() {
    cat >&2 <<'EOF'
usage: scripts/registry.sh <command> [name]

  namespace       registry and owner, e.g. ghcr.io/someone
  ref <name>      <namespace>/<name>

Environment:
  IMAGE_REGISTRY  overrides the namespace; CI sets it from the workflow
                  context. Otherwise it is derived from the origin remote.
EOF
}

# IMAGE_REGISTRY wins, so a build can publish somewhere other than the
# repo it was cloned from and CI does not depend on the checkout's remote.
# Otherwise the origin remote's owner, which is what lets a fork read its
# own cache and ship an ISO pointing at its own image with no edit.
namespace() {
    local registry="${IMAGE_REGISTRY:-}" url owner
    if [ -z "$registry" ]; then
        url="$(git config --get remote.origin.url 2> /dev/null || true)"
        owner="$(printf '%s\n' "$url" \
            | sed -n 's#^\(git@github\.com:\|ssh://git@github\.com/\|https://github\.com/\)\([^/]*\)/.*#\2#p')"
        [ -n "$owner" ] \
            || die "no IMAGE_REGISTRY set and no github origin remote to derive one from"
        registry="ghcr.io/${owner}"
    fi
    # ghcr.io rejects an uppercase reference and a GitHub owner may well be
    # capitalised, so the folding happens here once instead of at every
    # call site remembering ${IMAGE_REGISTRY,,}.
    printf '%s\n' "${registry,,}"
}

case "${1:-}" in
    namespace)
        namespace
        ;;
    ref)
        if [ "$#" -lt 2 ] || [ -z "$2" ]; then
            die "ref needs an image name"
        fi
        # Via a variable, not inline: a command substitution that fails
        # inside an argument list would leave printf to succeed with a
        # half-formed reference.
        ns="$(namespace)"
        printf '%s/%s\n' "$ns" "$2"
        ;;
    *)
        usage
        exit 1
        ;;
esac
