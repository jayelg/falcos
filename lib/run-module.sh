#!/bin/bash
# Runs one module inside its own Containerfile RUN layer. The generated
# blocks in the Containerfile (see scripts/gen-containerfile.sh) call this
# instead of module.sh directly, so the per-module conventions live in
# one place:
#
#   1. flavor gate    FLAVOR_GATE (set by a Containerfile.inc)
#                     skips the module on flavors it doesn't target
#   2. repo           sourced if present, idempotent via its REPO_ID
#   3. versions.sh    Renovate-tracked pins, sourced if present
#   4. variant        variants/<name>.sh overrides pins/flags, selected
#                     as <module>@<name> in modules.kdl
#   5. module.sh      the module's own install logic (sourced, so it
#                     inherits strict mode and the pins; MODDIR points
#                     at the module directory). Optional: a pure-file
#                     module (just a files/ overlay) omits it.
#   6. selinux/       each *.te compiled and installed as a policy module
#   7. files/         overlay copied verbatim into the image
#   8. justfile.inc   appended to the goojust app recipes
#   9. flatpaks.list  appended to /usr/share/falcos/default-flatpaks;
#                     one flatpak ID per line, installed at first boot

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

if [ -n "${MODULE_VARIANT:-}" ]; then
    # shellcheck source=/dev/null
    source "$MODDIR/variants/${MODULE_VARIANT}.sh"
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

if [ -f "$MODDIR/justfile.inc" ]; then
    mkdir -p /usr/share/goojust
    cat "$MODDIR/justfile.inc" >> /usr/share/goojust/justfile.apps
fi

if [ -f "$MODDIR/flatpaks.list" ]; then
    mkdir -p /usr/share/falcos
    cat "$MODDIR/flatpaks.list" >> /usr/share/falcos/default-flatpaks
fi
