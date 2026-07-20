# base

Pure-file base-system layer (no install step), applied first so it is the
cheapest layer to edit.

## Files

- `45-falcos-base.preset` -- disables `sshd` (the base image enables it; unwanted on a single-user desktop)
- coredump lockdown -- `coredump.conf.d/99-disable.conf`, `system.conf.d/99-coredump.conf`, `user.conf.d/99-coredump.conf`, `limits.d/99-disable-coredumps.conf`
- PAM policy -- `faillock.conf`, `pwquality.conf`
- `coreos-sulogin-force-generator`, `grub2-os-prober-regen`
- branding -- os-release `distributor-logo-symbolic.svg` + plymouth `watermark.png`
