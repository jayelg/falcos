#!/bin/bash
# Runs after all install phases. Copies files/common, restores systemctl,
# regenerates the initramfs, applies the falcos systemd presets and the
# remaining baked tweaks (bootloader, SELinux workaround).

set -ouex pipefail

# files/common is consumed at boot/runtime, not during the build. Copying
# it in this last layer means edits to it never rebuild the layers above.
[ -d "/ctx/files/common" ] && cp -rT /ctx/files/common "/"

# Restore systemctl (stubbed in phase-setup.sh)
rm /usr/bin/systemctl
mv /usr/bin/systemctl.bak /usr/bin/systemctl

### Regenerate initramfs
#   --add ostree   required for atomic updates
#   --add crypt    LUKS passphrase prompting
#   --add plymouth boot splash / graphical passphrase prompt (only when
#                  installed, it comes with the kde-desktop component)
# kernel-cachyos-core normally, kernel-core when built with KERNEL=stock
for pkg in kernel-cachyos-core kernel-core; do
    rpm -q "$pkg" &>/dev/null || continue
    KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' "$pkg")"
    break
done
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

### Signing policy
# Merge a sigstoreSigned entry into the base image policy.json.
# Namespace-scoped so one entry covers both flavor images.
python3 << 'PYEOF'
import json, os
path = '/etc/containers/policy.json'
p = json.load(open(path)) if os.path.exists(path) else {'default': [{'type': 'reject'}], 'transports': {}}
p.setdefault('transports', {}).setdefault('docker', {})['ghcr.io/jayelg'] = [
    {'type': 'sigstoreSigned', 'keyPath': '/etc/pki/containers/falcos.pub', 'signedIdentity': {'type': 'matchRepository'}}
]
json.dump(p, open(path, 'w'), indent=2)
PYEOF

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
# COMPONENTS.list takes its service enablement with it. Deliberately not
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

# Fedora countme telemetry, off for this image. Only the timer is masked so
# `rpm-ostree countme` still works manually. The timer elapses during sleep
# and fires on resume before the network is up, leaving a failed unit; if
# unmasked, the rpm-ostree-countme.service.d drop-in adds retries for that.
systemctl mask rpm-ostree-countme.timer
