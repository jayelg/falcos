#!/bin/bash
# Runs after common/core and common/frequent have both installed everything
# — copies files/common, restores systemctl, regenerates the initramfs
# against the final module set, and enables services.

set -ouex pipefail

# files/common is copied here, not in phase-setup.sh, since everything in it
# is consumed at boot/runtime by systemd units rather than read during any
# core/frequent script's own execution — deferring it here means editing any
# of those files never busts the expensive layers above (see Containerfile).
# The two exceptions that are genuinely read mid-build (sb_cert.der,
# 99-hardening) get copied separately, right where each is first needed.
[ -d "/ctx/files/common" ] && cp -rT /ctx/files/common "/"

# Restore systemctl
rm /usr/bin/systemctl
mv /usr/bin/systemctl.bak /usr/bin/systemctl

### Regenerate initramfs
# Picks up plymouth and, on desktop, dracut.conf.d/99-vfio.conf.
#   --add ostree   required for atomic updates
#   --add crypt    LUKS passphrase prompting
#   --add plymouth boot splash / graphical passphrase prompt
KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-cachyos-core)"
export DRACUT_NO_XATTR=1
dracut --force --no-hostonly --reproducible --add "ostree crypt plymouth" \
    --kver "$KVER" \
    "/usr/lib/modules/${KVER}/initramfs.img"

# Relocate /opt payloads (e.g. mullvad-vpn) into /usr, symlinked from
# /var/opt at runtime via tmpfiles. Content under /var only seeds a
# machine's /var on first install and is never updated by `bootc upgrade`;
# /usr content is delivered on every upgrade.
mkdir -p /usr/lib/opt
tmpfiles="/usr/lib/tmpfiles.d/zz-opt-symlinks.conf"
printf 'd /var/opt 0755 root root -\n' > "$tmpfiles"
for d in /opt/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    cp -a "$d" "/usr/lib/opt/${name}"
    # Escape spaces for tmpfiles' whitespace-separated fields (e.g. "Mullvad VPN").
    esc="${name// /\\x20}"
    printf 'L+ /var/opt/%s - - - - /usr/lib/opt/%s\n' "$esc" "$esc" >> "$tmpfiles"
done
rm -rf /opt
mv /opt.bak /opt

### Signing policy — merge sigstoreSigned entry into base image policy.json
python3 << 'PYEOF'
import json, os
path = '/etc/containers/policy.json'
p = json.load(open(path)) if os.path.exists(path) else {'default': [{'type': 'reject'}], 'transports': {}}
# Namespace-scoped (not per-repo) so one entry covers both flavor images.
p.setdefault('transports', {}).setdefault('docker', {})['ghcr.io/jayelg'] = [
    {'type': 'sigstoreSigned', 'keyPath': '/etc/pki/containers/falcos.pub', 'signedIdentity': {'type': 'matchRepository'}}
]
json.dump(p, open(path, 'w'), indent=2)
PYEOF

source /ctx/enable-services.sh
