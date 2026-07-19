# hardened-malloc:latest

GrapheneOS's hardened_malloc allocator, wired system-wide via `files/common/etc/environment.d/30-hardened-malloc.conf` (LD_PRELOAD).

**Packages:** hardened_malloc, no_rlimit_as (from secureblue repo, enabled=0, installed with `--enablerepo='secureblue'`)

**Repo dependency:** secureblue (shared with trivalent; idempotent via repo-discovery)
