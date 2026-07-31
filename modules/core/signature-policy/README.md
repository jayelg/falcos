# signature-policy

Makes the image verify signatures on its own updates. Pure-file overlay
plus a `finalize.sh`; no package install.

Split out of [auto-updates](../auto-updates) because verifying an update
and fetching one on a timer are separate decisions. A machine can verify
without auto-updating — a manual `bootc upgrade` consults the same policy
— but auto-updating without verifying is the configuration nobody wants,
so `auto-updates` declares `requires "signature-policy"` and delisting
this module fails lint rather than quietly producing an image that pulls
unverified updates on a timer.

## Files

- `pki/containers/cosign.pub` -- the public half of the CI signing key.
  Declared `provides-file`, so lint fails if the finished image does not
  carry it

## finalize.sh

Runs in the finalize layer, which is where the final image's policy.json
exists. Writes `registries.d/10-sigstore.yaml` to enable sigstore
attachments, and merges a `sigstoreSigned` entry naming the key above as
its `keyPath` into `/etc/containers/policy.json`.

Both are scoped to `IMAGE_REGISTRY`, which scripts/registry.sh derives
from the git remote, so a fork verifies its own images without editing
this module. A build with no namespace to derive says so and leaves the
policy alone rather than trusting a namespace nobody asked for.

## The other half of the key

The private half is a GitHub Actions secret; build.yml signs each pushed
digest with it and then verifies the result against this file, resolving
its path with `manifest find-provider /etc/pki/containers/cosign.pub` so
the workflow does not name this module.
