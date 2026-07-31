# Finalize-stage hook (sourced by 99-finalize.sh after systemctl is
# restored). The merge needs the final image's policy.json, which the base
# image ships and earlier layers may still rewrite, so it cannot run in
# this module's own build layer.

### Signing policy
# Merge a sigstoreSigned entry into the base image policy.json so `bootc
# upgrade` verifies signatures. Namespace-scoped so one entry covers both
# flavor images. The key this names ships in this module's files/ overlay
# and is declared as a contract file, so an image carrying this policy
# without the key fails lint rather than rejecting its first upgrade.
python3 << 'PYEOF'
import json, os
path = '/etc/containers/policy.json'
p = json.load(open(path)) if os.path.exists(path) else {'default': [{'type': 'reject'}], 'transports': {}}
p.setdefault('transports', {}).setdefault('docker', {})['ghcr.io/jayelg'] = [
    {'type': 'sigstoreSigned', 'keyPath': '/etc/pki/containers/cosign.pub', 'signedIdentity': {'type': 'matchRepository'}}
]
json.dump(p, open(path, 'w'), indent=2)
PYEOF
