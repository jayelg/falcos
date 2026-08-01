# auto-updates

The OS self-update mechanism: the upstream bootc timer, tuned. Pure-file
overlay plus a `finalize.sh`; no package install. The bootc-updates GUI
notifier that sits on top of this lives in [goojust](../goojust).

Signature verification is not here. It lives in
[signature-policy](../signature-policy), which this module `requires`:
updating unattended is only safe because what gets pulled is verified, so
the dependency is declared and lint enforces it.

## Files

- `bootc-fetch-apply-updates.{service,timer}.d/10-override.conf` -- tunes the upstream bootc auto-update timer/service
- `rpm-ostree-countme.service.d/10-override.conf` -- resume-retry drop-in for the countme service
- `45-module-updates.preset` -- enables `bootc-fetch-apply-updates.timer`

## finalize.sh

Runs in the finalize layer (needs real systemctl): masks
`rpm-ostree-countme.timer` (Fedora telemetry off; manual `rpm-ostree
countme` still works).

## justfile.inc

Ships the `update` recipe: updates the system image and then flatpaks,
refusing to run while the automatic update service is active.
