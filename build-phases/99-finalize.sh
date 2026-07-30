#!/bin/bash
# Runs after all install phases: restores systemctl, regenerates the
# initramfs, applies the falcos systemd presets, runs per-module
# finalize.sh hooks, and the remaining global tweaks (bootloader, SELinux
# workaround). Only genuinely global, run-once operations live here;
# module-owned finalize logic lives in each module's finalize.sh.

set -ouex pipefail

# Restore systemctl (stubbed in 00-setup.sh)
rm /usr/bin/systemctl
mv /usr/bin/systemctl.bak /usr/bin/systemctl

### Regenerate initramfs
#   --add ostree   required for atomic updates
#   --add crypt    LUKS passphrase prompting
#   --add plymouth boot splash / graphical passphrase prompt (only when
#                  installed, it comes with the kde-desktop module)
# Kernel package identity is written by the kernel module at
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
# Modules ship *falcos*.preset files in their files/ overlays; only those
# presets are applied here, so a module removed from modules.kdl takes
# its service enablement with it. Deliberately not `systemctl
# preset-all`, which would re-apply Fedora's defaults to every unit in
# the image.
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

### Module finalize hooks
# Some modules need real systemctl or must run after every other module
# (e.g. service masking, image policy edits). That logic lives in the
# module's finalize.sh, sourced here in resolved build order and
# flavor-gated exactly like the build layers. MODDIR points at the module
# dir, as in run-module.sh.
#
# The order arrives resolved, as FINALIZE_ORDER, because the generator
# already knows it: it is the one thing that reads the module list, and
# reparsing that list here was a second implementation of the format
# with nothing to keep the two agreeing. Each token is <path>, or
# <path>:<flavor> for a gated module, since which hooks run is the one
# part that stays a per-flavor decision.
run_module_finalize() {
    local entry name gate dir entries=()
    read -ra entries <<< "${FINALIZE_ORDER:-}"
    for entry in "${entries[@]}"; do
        name="${entry%%:*}"
        gate=""
        [ "$entry" = "$name" ] || gate="${entry#*:}"
        [ -z "$gate" ] || [ "$gate" = "${FLAVOR:-}" ] || continue
        dir="/ctx/modules/${name}"
        MODDIR="$dir"; export MODDIR
        # shellcheck source=/dev/null
        source "$dir/finalize.sh"
    done
}
run_module_finalize
