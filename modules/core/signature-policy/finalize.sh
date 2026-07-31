# Finalize-stage hook (sourced by 99-finalize.sh after systemctl is
# restored). The merge needs the final image's policy.json, which the base
# image ships and earlier layers may still rewrite, so it cannot run in
# this module's own build layer.
#
# Both files are scoped to IMAGE_REGISTRY, the namespace this checkout
# publishes into, which scripts/registry.sh derives from the git remote
# and scripts/build.sh passes in. The module names no registry of its own,
# so a fork's image verifies the fork's own updates.

if [ -z "${IMAGE_REGISTRY:-}" ]; then
    echo "signature-policy: no registry namespace to scope the policy to;" \
        "this image will not verify its own updates" >&2
else
    ### Sigstore attachments
    # Where the signatures for that namespace live. Namespace-scoped, so
    # one entry covers every flavor image.
    mkdir -p /etc/containers/registries.d
    cat > /etc/containers/registries.d/10-sigstore.yaml << EOF
docker:
  ${IMAGE_REGISTRY}:
    use-sigstore-attachments: true
EOF

    ### Signing policy
    # Merge a sigstoreSigned entry into the base image policy.json so
    # `bootc upgrade` verifies signatures. The key this names ships in
    # this module's files/ overlay and is declared as a contract file, so
    # an image carrying this policy without the key fails lint rather than
    # rejecting its first upgrade.
    python3 << 'PYEOF'
import json, os
path = '/etc/containers/policy.json'
p = json.load(open(path)) if os.path.exists(path) else {'default': [{'type': 'reject'}], 'transports': {}}
p.setdefault('transports', {}).setdefault('docker', {})[os.environ['IMAGE_REGISTRY']] = [
    {'type': 'sigstoreSigned', 'keyPath': '/etc/pki/containers/cosign.pub', 'signedIdentity': {'type': 'matchRepository'}}
]
json.dump(p, open(path, 'w'), indent=2)
PYEOF
fi
