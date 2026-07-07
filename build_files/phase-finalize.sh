#!/bin/bash
# Runs after all install phases. Copies files/common, restores systemctl,
# regenerates the initramfs and enables services.

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
#   --add plymouth boot splash / graphical passphrase prompt
KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-cachyos-core)"
export DRACUT_NO_XATTR=1
dracut --force --no-hostonly --reproducible --add "ostree crypt plymouth" \
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

source /ctx/enable-services.sh
