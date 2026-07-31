# bootloader

Dual boot support: GRUB is told it may run os-prober, and the regeneration
that actually runs it ships as a recipe rather than a service.

**Files installed:**
- `usr/libexec/grub2-os-prober-regen` -- remounts `/boot` read-write,
  regenerates the EFI or BIOS `grub.cfg`, remounts read-only

**module.sh:** appends `GRUB_DISABLE_OS_PROBER=false` to
`/etc/default/grub`, which is what lets the generator probe for other
installed systems at all.

**justfile.inc:** `regenerate-grub`, which runs the helper above.

## Notes

On demand rather than automatic, because it currently cannot work.
`grub2-probe` fails to resolve composefs's root mount ("failed to get
canonical path of `composefs'"), so `grub2-mkconfig` always fails here.
That is an open upstream bug (ostreedev/ostree#3198, ublue-os/bazzite#2519)
with no fix in the ostree/bootc ecosystem yet, and Bazzite's own
`ujust regenerate-grub` hits the identical failure. Keeping it as a
manually run recipe means it is ready to work once that is fixed, instead
of being a permanently failing systemd unit in the meantime.
