# auto-updates

The OS self-update + image-signing mechanism. Pure-file overlay plus a
`finalize.sh`; no package install. The bootc-updates GUI notifier that sits
on top of this lives in [falcos-tools](../falcos-tools).

## Files

- `registries.d/falcos.yaml` -- enables sigstore attachments for `ghcr.io/jayelg`
- `bootc-fetch-apply-updates.{service,timer}.d/10-override.conf` -- tunes the upstream bootc auto-update timer/service
- `rpm-ostree-countme.service.d/10-override.conf` -- resume-retry drop-in for the countme service
- `45-falcos-updates.preset` -- enables `bootc-fetch-apply-updates.timer`

## finalize.sh

Runs in the finalize layer (needs the final image / real systemctl):

- Merges a `sigstoreSigned` entry for `ghcr.io/jayelg` into
  `/etc/containers/policy.json`, so `bootc upgrade` verifies signatures
  against the baked `falcos.pub`.
- Masks `rpm-ostree-countme.timer` (Fedora telemetry off; manual
  `rpm-ostree countme` still works).
