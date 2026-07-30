#!/bin/bash
# In-image assertions that run after every build phase and module finalize
# hook. Called from the Containerfile LINTING section so a failed check
# stops the image before it is published. Today bootc container lint is
# the only pre-publish gate; these add coverage for the units, kernel and
# paths the image actually ships.
#
# Each check is independent: a failure in one does not skip the rest, and
# every failure is reported before the script exits non-zero.

set -euo pipefail

failures=0
fail() {
    echo "FAIL: $*" >&2
    failures=$((failures + 1))
}

# ---- bootc configuration ------------------------------------------------
echo "==> bootc install print-configuration"
if bootc install print-configuration > /dev/null; then
    echo "    ok"
else
    fail "bootc install print-configuration failed to parse"
fi

# ---- initramfs -----------------------------------------------------------
echo "==> initramfs"
kernel_pkg="$(cat /usr/lib/falcos/kernel-package 2>/dev/null || echo 'kernel-core')"
if kver="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' "$kernel_pkg" 2>/dev/null)"; then
    initramfs="/usr/lib/modules/${kver}/initramfs.img"
    if [ -f "$initramfs" ]; then
        echo "    ${initramfs} present"
    else
        fail "initramfs missing at ${initramfs}"
    fi
else
    fail "cannot determine kernel version from package ${kernel_pkg}"
fi

# ---- /usr/lib/opt symlinks -----------------------------------------------
echo "==> /usr/lib/opt symlinks"
tmpfiles="/usr/lib/tmpfiles.d/zz-opt-symlinks.conf"
if [ -f "$tmpfiles" ]; then
    while read -r type path _ _ _ target _; do
        case "$type" in
            L+|L)
                # unescape \x20 back to spaces for the filesystem check
                target="${target//\\x20/ }"
                if [ ! -e "$target" ]; then
                    fail "${path} -> ${target}: target does not exist"
                else
                    echo "    ${path} -> ${target} ok"
                fi
                ;;
        esac
    done < "$tmpfiles"
else
    echo "    (no /usr/lib/opt symlinks declared)"
fi

# ---- expected binaries ---------------------------------------------------
echo "==> expected binaries"
for bin in bootc systemctl rpm-ostree; do
    if command -v "$bin" > /dev/null 2>&1; then
        echo "    ${bin} ok"
    else
        fail "${bin} not on PATH"
    fi
done

# ---- systemd unit verification -------------------------------------------
# Every unit referenced by a falcos preset must exist as a file and, for
# system units, parse cleanly through systemd-analyze verify. User units
# are checked for file existence only: systemd-analyze verify --user
# needs a running user manager, which a container build does not have.
# Only the preset files that were actually shipped are checked, so a
# module removed from modules.kdl takes its unit checks with it.
#
# systemd-analyze verify can run offline (no PID 1 needed), but
# systemctl show requires a running systemd, so the file search uses
# find against the standard unit paths.
echo "==> systemd unit verification"
checked=0
for scope in system user; do
    unit_dirs="/usr/lib/systemd/${scope} /etc/systemd/${scope}"
    for preset in "/usr/lib/systemd/${scope}-preset/"*falcos*.preset; do
        [ -f "$preset" ] || continue
        echo "    ${preset}"
        while read -r verb unit; do
            case "$verb" in
                enable | disable) ;;
                *) continue ;;
            esac
            checked=$((checked + 1))

            # Find the unit file in standard paths. Units shipped by
            # modules land in /usr/lib/systemd; /etc is for image-level
            # overrides and the base image.
            unit_file=""
            # word-split on purpose: each dir is a separate argument
            # shellcheck disable=SC2086
            unit_file="$(find ${unit_dirs} -name "${unit}" -print -quit 2>/dev/null || true)"
            if [ -z "$unit_file" ] || [ ! -f "$unit_file" ]; then
                fail "${unit}: unit file not found in ${unit_dirs}"
                continue
            fi

            if [ "$scope" = "system" ]; then
                if systemd-analyze verify --no-pager "$unit" > /dev/null 2>&1; then
                    echo "        ${unit} ok"
                else
                    echo "        ${unit} FAILED (systemd-analyze verify:)"
                    systemd-analyze verify --no-pager "$unit" 2>&1 | sed 's/^/          /' >&2 || true
                    fail "${unit} did not verify"
                fi
            else
                echo "        ${unit} ok (exists)"
            fi
        done < "$preset"
    done
done

if [ "$checked" -eq 0 ]; then
    fail "no falcos preset files found"
fi

# ---- summary -------------------------------------------------------------
echo
if [ "$failures" -eq 0 ]; then
    echo "All validation checks passed."
else
    echo "${failures} validation check(s) failed." >&2
    exit 1
fi
