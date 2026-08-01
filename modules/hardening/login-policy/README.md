# login-policy

Who gets a shell on this machine, and how. Every file here answers that
question for one way in: over the network, at a login prompt, or from the
bootloader.

Pure-file overlay, no install step.

**Files installed:**
- `usr/lib/systemd/system-preset/45-module-login-policy.preset` --
  disables `sshd`. The base image enables it, and a single-user desktop
  does not want a network login it never asked for
- `etc/security/faillock.conf` -- locks an account for 15 minutes after 5
  consecutive failed logins
- `etc/security/pwquality.conf` -- 12 character minimum, enforced for root
  as well
- `usr/lib/systemd/system-generators/coreos-sulogin-force-generator` --
  sets `SYSTEMD_SULOGIN_FORCE=1` when rescue or emergency is requested
  from the kernel cmdline, so those targets work on a system with a locked
  root password, which is the Fedora default

## Notes

The sulogin generator is a loosening, not a tightening, and is here
because it belongs to the same question. Reaching it needs console or
GRUB access, which is already enough to boot `init=/bin/bash`, so the
target it is bypassing was not protecting anything from someone standing
there. It does not bypass an assigned root password, only a locked one,
and it does not apply to an fsck failure.
