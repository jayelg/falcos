[root](../../README.md) / [build_files](../README.md) / **common**

Shared build infrastructure that doesn't belong to any single component. Flavor agnostic so the layer cache is shared across desktop and laptop builds.

- **Repo discovery** -- Containerfile baked step that sources each component's `repo` file (idempotent via REPO_ID guard)
- **Bootloader** -- `GRUB_DISABLE_OS_PROBER=false` baked step
- **Kernel stale-management** -- removes stock kernel when cachyos is present (bootc lint requirement)
- **SELinux composefs workaround** -- temporary execmem policy for composefs/overlay mmap bug
- **Flavor + finalize** -- `phase-flavor.sh` and `phase-finalize.sh` run after all components
