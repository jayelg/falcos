# finalize.sh — run-once logic that needs the REAL systemctl or the final
# assembled image. OPTIONAL. Sourced by 99-finalize.sh (not run-module.sh)
# after systemctl is restored, in image.kdl order and flavor-gated, so:
#   - `systemctl mask/enable/disable` works here (it's stubbed in the build
#     layers) — though simple enablement should use a files/ preset instead
#   - the whole image exists, so you can edit files other modules installed
#     (e.g. merge into /etc/containers/policy.json — see core/auto-updates)
#   - $MODDIR points at this module's directory
#
# Genuinely global operations (/opt relocation, SELinux workaround,
# service enablement) live in 99-finalize.sh. Hooks are sourced in build
# order, but do not write one that depends on that: a module needing
# something another module's hook does shares a collected file with it
# instead. Initramfs regeneration is the example: the kernel module's
# hook builds it once, from the dracut module names any module can
# contribute by shipping a dracut.modules.

# Example: mask a unit that only makes sense to disable on the final image.
# systemctl mask example-noisy.timer
:
