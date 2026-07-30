#!/bin/bash
# Runs one module inside its own Containerfile RUN layer. The generated
# blocks in the Containerfile (see scripts/gen-containerfile.sh) call this
# instead of module.sh directly, so the per-module conventions live in
# one place:
#
#   1. flavor gate    FLAVOR_GATE (set by the generated block from the
#                     flavor the module is listed under in modules.kdl)
#                     skips the module on flavors it doesn't target
#   2. repo           sourced if present, idempotent via its REPO_ID
#   3. versions.sh    Renovate-tracked pins, sourced if present
#   4. module.sh      the module's own install logic (sourced, so it
#                     inherits strict mode, the pins and OPT_* for every
#                     option the module declares; MODDIR points at the
#                     module directory). Optional: a pure-file module
#                     (just a files/ overlay) omits it.
#   5. selinux/       each *.te compiled and installed as a policy module
#   6. files/         overlay copied verbatim into the image
#   7. collected      each file this module ships that another module
#                     collects. The pairs arrive resolved in
#                     MODULE_COLLECT, so no path is written down here

set -ouex pipefail

MODDIR="${1:?usage: run-module.sh <module dir>}"
export MODDIR

# An empty FLAVOR is the ungated build, not a missing value: a gated
# module skips there, exactly as it does on a flavor it does not target.
if [ -n "${FLAVOR_GATE:-}" ]; then
    case ",${FLAVOR_GATE}," in
        *",${FLAVOR:-},"*) ;;
        *)
            echo "Skipping $(basename "$MODDIR"): not built for '${FLAVOR:-the ungated build}'"
            exit 0
            ;;
    esac
fi

if [ -f "$MODDIR/repo" ]; then
    REPO_ID="$(sed -n 's/^REPO_ID="\(.*\)"/\1/p' "$MODDIR/repo")"
    if [ -n "$REPO_ID" ] && [ -f "/etc/yum.repos.d/${REPO_ID}.repo" ]; then
        echo "Repo ${REPO_ID} already configured, skipping"
    else
        # shellcheck source=/dev/null
        source "$MODDIR/repo"
    fi
fi

if [ -f "$MODDIR/versions.sh" ]; then
    # shellcheck source=/dev/null
    source "$MODDIR/versions.sh"
fi

# A module may be pure files (no install logic): its module.sh is
# optional, so a directory drop is as valid a module as an app install.
if [ -f "$MODDIR/module.sh" ]; then
    # shellcheck source=/dev/null
    source "$MODDIR/module.sh"
fi

# Local SELinux policy: every selinux/*.te is compiled and installed at
# priority 200. Copied to /tmp first because install_selinux_module removes
# the source and the module dir is a read-only bind mount.
if [ -d "$MODDIR/selinux" ]; then
    # shellcheck source=/dev/null
    source /ctx/lib/selinux-helpers.sh
    for te in "$MODDIR"/selinux/*.te; do
        [ -f "$te" ] || continue
        cp "$te" "/tmp/$(basename "$te")"
        install_selinux_module "/tmp/$(basename "$te")"
    done
fi

if [ -d "$MODDIR/files" ]; then
    cp -rT "$MODDIR/files" /
fi

# Collected files. Another module declared that it collects this
# filename and where the build should put it; the generator resolved that
# into <file>=<destination> pairs for exactly the files this module ships.
# Nothing here knows about goojust or flatpaks, so a module can start
# collecting a new filename without this script being taught about it.
read -ra collected <<< "${MODULE_COLLECT:-}"
for pair in "${collected[@]}"; do
    src="$MODDIR/${pair%%=*}"
    dest="${pair#*=}"
    mkdir -p "$(dirname "$dest")"
    cat "$src" >> "$dest"
done
