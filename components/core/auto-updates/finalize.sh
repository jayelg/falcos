# Finalize-stage hook (sourced by 99-finalize.sh after systemctl is
# restored). These need the real systemctl / the final image policy, so
# they can't run in this component's own build layer.

### Signing policy
# Merge a sigstoreSigned entry into the base image policy.json so `bootc
# upgrade` verifies signatures. Namespace-scoped so one entry covers both
# flavor images. The key itself is baked by the Containerfile (cosign.pub).
python3 << 'PYEOF'
import json, os
path = '/etc/containers/policy.json'
p = json.load(open(path)) if os.path.exists(path) else {'default': [{'type': 'reject'}], 'transports': {}}
p.setdefault('transports', {}).setdefault('docker', {})['ghcr.io/jayelg'] = [
    {'type': 'sigstoreSigned', 'keyPath': '/etc/pki/containers/cosign.pub', 'signedIdentity': {'type': 'matchRepository'}}
]
json.dump(p, open(path, 'w'), indent=2)
PYEOF

# Fedora countme telemetry, off for this image. Only the timer is masked so
# `rpm-ostree countme` still works manually. The timer elapses during sleep
# and fires on resume before the network is up, leaving a failed unit; if
# unmasked, the rpm-ostree-countme.service.d drop-in (this component's
# files/ overlay) adds retries for that.
systemctl mask rpm-ostree-countme.timer
