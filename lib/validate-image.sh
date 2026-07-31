#!/bin/bash
# In-image assertions that run after module finalize hooks in the
# Containerfile LINTING section. A failed check stops the image before
# it is published. Each check is independent: all failures are reported
# before the script exits non-zero.

set -euo pipefail

failures=0
fail() {
    echo "FAIL: $*" >&2
    failures=$((failures + 1))
}

# bootc configuration
echo "==> bootc install print-configuration"
if bootc install print-configuration > /dev/null; then
    echo "    ok"
else
    fail "bootc install print-configuration failed to parse"
fi

# initramfs
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

# /usr/lib/opt symlinks
echo "==> /usr/lib/opt symlinks"
tmpfiles="/usr/lib/tmpfiles.d/zz-opt-symlinks.conf"
if [ -f "$tmpfiles" ]; then
    # Type Path Mode User Group Age Argument: the symlink target is the
    # Argument, four fields past Path, and Age is what one short lands on.
    while read -r type path _ _ _ _ target; do
        case "$type" in
            L+|L)
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

# expected binaries
echo "==> expected binaries"
for bin in bootc systemctl rpm-ostree; do
    if command -v "$bin" > /dev/null 2>&1; then
        echo "    ${bin} ok"
    else
        fail "${bin} not on PATH"
    fi
done

# Enablement symlinks for a unit under a config root. WantedBy and
# RequiredBy land in <target>.wants/ and <target>.requires/ one level
# down, an [Install] Alias lands beside them at the root, and a mask is a
# link to /dev/null rather than enablement.
enablement_links() {
    local root="$1" unit="$2" link
    [ -d "$root" ] || return 0
    while IFS= read -r link; do
        [ -n "$link" ] || continue
        [ "$(readlink "$link")" = /dev/null ] && continue
        printf '%s\n' "$link"
    done < <(find "$root" -maxdepth 2 -name "$unit" -type l 2>/dev/null || true)
}

# systemd unit verification
# Every unit referenced by a preset must exist as a file, and the preset
# must actually have been applied: 99-finalize.sh runs systemctl enable
# and disable, which write and remove symlinks under /etc/systemd/<scope>,
# so those symlinks are the evidence. Reading them off disk is what makes
# this an assertion about enablement rather than about a unit merely
# existing, and it needs no PID 1, which a container build has not got.
# System units also pass through systemd-analyze verify, but its dependency
# warnings are not fatal: device and mount units don't exist in a
# container build. User units skip verify because --user needs a
# running user manager. Unit files are found with find because
# systemctl show requires a running PID 1.
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

            # shellcheck disable=SC2086
            unit_file="$(find ${unit_dirs} -name "${unit}" -print -quit 2>/dev/null || true)"
            if [ -z "$unit_file" ] || [ ! -f "$unit_file" ]; then
                # disable on a missing unit is a no-op, not a config error
                if [ "$verb" = "enable" ]; then
                    fail "${unit}: unit file not found in ${unit_dirs}"
                else
                    echo "        ${unit} (not present, ${verb}d)"
                fi
                continue
            fi

            # systemctl enable and --global enable write here, and
            # systemctl disable removes what it wrote.
            config_root="/etc/systemd/${scope}"
            links="$(enablement_links "$config_root" "$unit")"
            if [ "$verb" = "enable" ] && [ -z "$links" ]; then
                fail "${unit}: preset enables it, but nothing under ${config_root} does"
            elif [ "$verb" = "disable" ] && [ -n "$links" ]; then
                fail "${unit}: preset disables it, but ${config_root} still enables it:" \
                    "$(echo "$links" | tr '\n' ' ')"
            fi

            if [ "$scope" = "system" ] && [ "$verb" = "enable" ]; then
                if out="$(systemd-analyze verify --no-pager "$unit" 2>&1)"; then
                    echo "        ${unit} enabled"
                else
                    echo "        ${unit} enabled, verify notes:"
                    # shellcheck disable=SC2001
                    echo "$out" | sed 's/^/          /' >&2 || true
                fi
            else
                echo "        ${unit} ${verb}d"
            fi
        done < "$preset"
    done
done

if [ "$checked" -eq 0 ]; then
    fail "no falcos preset files found"
fi

# summary
echo
if [ "$failures" -eq 0 ]; then
    echo "All validation checks passed."
else
    echo "${failures} validation check(s) failed." >&2
    exit 1
fi
