#!/usr/bin/env bash
# Fetches every out-of-tree module modules.kdl pins into
# modules/.remote/<name>/, so the generator can emit the same RUN block
# for it as for a module in this repository.
#
# Runs at generate time, on the host: scripts/gen-containerfile.sh and
# scripts/lint.sh both call it, so a build and a lint see the same tree
# and nothing inside the image ever fetches anything.
#
# The archive is verified against the pinned sha256 before it is
# extracted, through the same helper the modules themselves fetch with. A
# pin whose tree is already on disk costs one stamp comparison and no
# network, so a build stays offline once it has fetched.
set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck source=lib/fetch-helpers.sh
source lib/fetch-helpers.sh

remote_root="modules/.remote"
# What each fetched tree was fetched from. Outside the tree itself, so
# nothing lands in the build context that the module did not ship.
stamp_root="build/remote-modules"

die() {
    echo "fetch-modules: $*" >&2
    exit 1
}

# Not a process substitution: a manifest that does not parse has to stop
# the run rather than read as no pins at all.
remotes="$(./scripts/manifest.sh remotes)"
pins=()
[ -z "$remotes" ] || mapfile -t pins <<< "$remotes"

# A tree left behind by a pin that is no longer listed would still be
# copied into the ctx stage, so it is removed rather than ignored.
if [ -d "$remote_root" ]; then
    pinned="$(cut -d'|' -f1 <<< "$remotes")"
    for dir in "$remote_root"/*/; do
        [ -d "$dir" ] || continue
        name="$(basename "$dir")"
        if ! grep -qxF "$name" <<< "$pinned"; then
            echo "fetch-modules: ${name} is no longer pinned, removing"
            rm -rf "$dir" "${stamp_root}/${name}.pin"
        fi
    done
    rmdir "$remote_root" 2> /dev/null || true
fi

[ "${#pins[@]}" -gt 0 ] || exit 0

tmp=""
trap '[ -z "$tmp" ] || rm -rf "$tmp"' EXIT

for pin in "${pins[@]}"; do
    IFS='|' read -r name dir ref sha256 url path <<< "$pin"
    # The directory is replaced wholesale below, so it is checked to be
    # the one this script owns rather than trusted to be.
    [ "$dir" = "${remote_root}/${name}" ] || die "${name}: unexpected fetch directory ${dir}"

    # The whole pin, so a moved subtree or a re-pinned hash refetches
    # even when the ref did not change.
    stamp="${stamp_root}/${name}.pin"
    want="${sha256} ${url} ${path}"
    if [ -f "${dir}/module.kdl" ] && [ "$(cat "$stamp" 2> /dev/null)" = "$want" ]; then
        echo "fetch-modules: ${name} ${ref} is current"
        continue
    fi

    mkdir -p build
    tmp="$(mktemp -d build/fetch-module.XXXXXX)"
    # One leading directory is stripped: a forge names it for the ref, so
    # a pin that had to spell it would change on every bump.
    fetch_extract "$url" "$sha256" "$tmp" --strip-components=1

    src="$tmp"
    [ -z "$path" ] || src="${tmp}/${path}"
    [ -d "$src" ] || die "${name}: ${url} has no ${path:-module} in it"
    [ -f "${src}/module.kdl" ] || die "${name}: ${path:-the archive root} ships no module.kdl"

    rm -rf "$dir"
    mkdir -p "$(dirname "$dir")"
    cp -a "$src" "$dir"
    rm -rf "$tmp"
    tmp=""

    mkdir -p "$stamp_root"
    printf '%s\n' "$want" > "$stamp"
    echo "fetch-modules: ${name} ${ref} fetched and verified"
done
