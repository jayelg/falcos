# coredumps

Turns coredumps off. A dump of a crashed process is a copy of whatever it
held in memory, written to disk by a machine whose user did not ask for
it, and nothing here debugs from one.

Pure-file overlay, no install step.

**Files installed:**
- `etc/systemd/coredump.conf.d/99-disable.conf` -- `Storage=none`,
  `ProcessSizeMax=0`, so systemd-coredump keeps nothing
- `etc/systemd/system.conf.d/99-coredump.conf` and
  `etc/systemd/user.conf.d/99-coredump.conf` -- `DefaultLimitCORE=0` for
  both managers
- `etc/security/limits.d/99-disable-coredumps.conf` -- the same limit for
  sessions that come up through PAM rather than systemd
