#!/bin/bash
# Runs one component inside its own Containerfile RUN layer. The generated
# blocks in the Containerfile (see scripts/gen-containerfile.sh) call this
# instead of the component.sh directly, so the per-component conventions
# live in one place:
#
#   1. flavor gate    COMPONENT_FLAVORS (set by a Containerfile.part)
#                     skips the component on flavors it doesn't target
#   2. repo           sourced if present, idempotent via its REPO_ID
#   3. versions.sh    Renovate-tracked pins, sourced if present
#   4. variant        variants/<name>.sh overrides pins/flags, selected
#                     as <component>@<name> in COMPONENTS.list
#   5. component.sh   the component's own install logic (sourced, so it
#                     inherits strict mode and the pins; COMPDIR points
#                     at the component directory). Optional: a pure-file
#                     component (just a files/ overlay) omits it.
#   6. selinux/       each *.te compiled and installed as a policy module
#   7. files/         overlay copied verbatim into the image
#   8. justfile.inc   appended to the falcos-cli app recipes
#   9. flatpaks.list  appended to /usr/share/falcos/default-flatpaks;
#                     one flatpak ID per line, installed at first boot

set -ouex pipefail

COMPDIR="${1:?usage: run-component.sh <component dir>}"
export COMPDIR

if [ -n "${COMPONENT_FLAVORS:-}" ]; then
    case ",${COMPONENT_FLAVORS}," in
        *",${FLAVOR:?},"*) ;;
        *)
            echo "Skipping $(basename "$COMPDIR"): not built for flavor '${FLAVOR}'"
            exit 0
            ;;
    esac
fi

if [ -f "$COMPDIR/repo" ]; then
    REPO_ID="$(sed -n 's/^REPO_ID="\(.*\)"/\1/p' "$COMPDIR/repo")"
    if [ -n "$REPO_ID" ] && [ -f "/etc/yum.repos.d/${REPO_ID}.repo" ]; then
        echo "Repo ${REPO_ID} already configured, skipping"
    else
        # shellcheck source=/dev/null
        source "$COMPDIR/repo"
    fi
fi

if [ -f "$COMPDIR/versions.sh" ]; then
    # shellcheck source=/dev/null
    source "$COMPDIR/versions.sh"
fi

if [ -n "${COMPONENT_VARIANT:-}" ]; then
    # shellcheck source=/dev/null
    source "$COMPDIR/variants/${COMPONENT_VARIANT}.sh"
fi

# A component may be pure files (no install logic): its component.sh is
# optional, so a directory drop is as valid a component as an app install.
if [ -f "$COMPDIR/component.sh" ]; then
    # shellcheck source=/dev/null
    source "$COMPDIR/component.sh"
fi

# Local SELinux policy: every selinux/*.te is compiled and installed at
# priority 200. Copied to /tmp first because install_selinux_module removes
# the source and the component dir is a read-only bind mount.
if [ -d "$COMPDIR/selinux" ]; then
    # shellcheck source=/dev/null
    source /ctx/lib/selinux-helpers.sh
    for te in "$COMPDIR"/selinux/*.te; do
        [ -f "$te" ] || continue
        cp "$te" "/tmp/$(basename "$te")"
        install_selinux_module "/tmp/$(basename "$te")"
    done
fi

if [ -d "$COMPDIR/files" ]; then
    cp -rT "$COMPDIR/files" /
fi

if [ -f "$COMPDIR/justfile.inc" ]; then
    mkdir -p /usr/share/falcos
    cat "$COMPDIR/justfile.inc" >> /usr/share/falcos/justfile.apps
fi

if [ -f "$COMPDIR/flatpaks.list" ]; then
    mkdir -p /usr/share/falcos
    cat "$COMPDIR/flatpaks.list" >> /usr/share/falcos/default-flatpaks
fi
