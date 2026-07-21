#!/bin/bash
# Runs after all install phases: restores systemctl, regenerates the
# initramfs, applies the falcos systemd presets, runs per-component
# finalize.sh hooks, and the remaining global tweaks (bootloader, SELinux
# workaround). Only genuinely global, run-once operations live here;
# component-owned finalize logic lives in each component's finalize.sh.

set -ouex pipefail

# Restore systemctl (stubbed in 00-setup.sh)
rm /usr/bin/systemctl
mv /usr/bin/systemctl.bak /usr/bin/systemctl

### Regenerate initramfs
#   --add ostree   required for atomic updates
#   --add crypt    LUKS passphrase prompting
#   --add plymouth boot splash / graphical passphrase prompt (only when
#                  installed, it comes with the kde-desktop component)
# Kernel package identity is written by the kernel component at
# /usr/lib/falcos/kernel-package so 99-finalize doesn't need to know
# which kernel variant is installed.
KERNEL_PKG="$(cat /usr/lib/falcos/kernel-package 2>/dev/null || echo 'kernel-core')"
KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' "$KERNEL_PKG")"
DRACUT_MODULES="ostree crypt"
rpm -q plymouth &>/dev/null && DRACUT_MODULES+=" plymouth"
export DRACUT_NO_XATTR=1
dracut --force --no-hostonly --reproducible --add "$DRACUT_MODULES" \
    --kver "$KVER" \
    "/usr/lib/modules/${KVER}/initramfs.img"

# Relocate /opt payloads (e.g. mullvad-vpn) into /usr, symlinked from
# /var/opt via tmpfiles. /var content only seeds a machine on first
# install; /usr content is delivered on every upgrade.
mkdir -p /usr/lib/opt
tmpfiles="/usr/lib/tmpfiles.d/zz-opt-symlinks.conf"
printf 'd /var/opt 0755 root root -\n' > "$tmpfiles"
for d in /opt/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    cp -a "$d" "/usr/lib/opt/${name}"
    # tmpfiles fields are whitespace separated, escape spaces (e.g. "Mullvad VPN")
    esc="${name// /\\x20}"
    printf 'L+ /var/opt/%s - - - - /usr/lib/opt/%s\n' "$esc" "$esc" >> "$tmpfiles"
done
rm -rf /opt
mv /opt.bak /opt

### Bootloader
# Let GRUB discover other installed OSes (dual boot).
echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub

### SELinux Policy: composefs/overlay execmem workaround
# A composefs/overlay mmap bug mislabels legitimate userspace execmem
# mappings as kernel_t (ublue-os/akmods#537). Drop once fixed upstream.
cat <<'EOF' > /tmp/composefs_execmem.te
module composefs_execmem 0.1;

require {
	type kernel_t;
	class process execmem;
}

allow kernel_t self:process execmem;
EOF
source /ctx/lib/selinux-helpers.sh
install_selinux_module /tmp/composefs_execmem.te

### Service enablement
# Components ship *falcos*.preset files in their files/ overlays; only
# those presets are applied here, so a component removed from
# components.list takes its service enablement with it. Deliberately not
# `systemctl preset-all`, which would re-apply Fedora's defaults to every
# unit in the image.
apply_falcos_presets() {
    local scope="$1" dir="$2" flag=() f verb unit
    [ "$scope" = "user" ] && flag=(--global)
    for f in "$dir"/*falcos*.preset; do
        [ -f "$f" ] || continue
        while read -r verb unit; do
            case "$verb" in
                enable) systemctl "${flag[@]}" enable "$unit" ;;
                disable) systemctl "${flag[@]}" disable "$unit" ;;
                *) ;; # comments and blank lines
            esac
        done < "$f"
    done
}
apply_falcos_presets system /usr/lib/systemd/system-preset
apply_falcos_presets user /usr/lib/systemd/user-preset

### Component finalize hooks
# Some components need real systemctl or must run after every other
# component (e.g. service masking, image policy edits). That logic lives in
# the component's finalize.sh, sourced here in components.list order and
# flavor-gated exactly like the build layers. COMPDIR points at the
# component dir, as in run-component.sh.
run_component_finalize() {
    local current_flavor="" line entry name d dir
    while IFS= read -r line; do
        entry="${line%%#*}"
        entry="${entry//[[:space:]]/}"
        [ -z "$entry" ] && continue
        if [[ "$entry" =~ ^\[([a-z][a-z0-9-]*)\]$ ]]; then
            section_name="${BASH_REMATCH[1]}"
            if [ "$section_name" = "common" ]; then
                current_flavor=""
            else
                current_flavor="$section_name"
            fi
            continue
        fi
        # skip components gated to a different flavor
        [ -n "$current_flavor" ] && [ "$current_flavor" != "${FLAVOR:?}" ] && continue
        name="${entry%%@*}"
        d="/ctx/components/${name}"
        dir=""
        [ -d "$d" ] && dir="$d"
        if [ -n "$dir" ] && [ -f "$dir/finalize.sh" ]; then
            COMPDIR="$dir"; export COMPDIR
            # shellcheck source=/dev/null
            source "$dir/finalize.sh"
        fi
    done < /ctx/components.list
}
run_component_finalize
