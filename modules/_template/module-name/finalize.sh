# finalize.sh — run-once logic that needs the REAL systemctl or the final
# assembled image. OPTIONAL. Sourced by 99-finalize.sh (not run-module.sh)
# after systemctl is restored, in modules.kdl order and flavor-gated, so:
#   - `systemctl mask/enable/disable` works here (it's stubbed in the build
#     layers) — though simple enablement should use a files/ preset instead
#   - the whole image exists, so you can edit files other modules installed
#     (e.g. merge into /etc/containers/policy.json — see core/auto-updates)
#   - $MODDIR points at this module's directory
#
# Keep genuinely global, run-once operations (initramfs regen, /opt) in
# 99-finalize.sh itself — those aren't owned by any single module.

# Example: mask a unit that only makes sense to disable on the final image.
# systemctl mask example-noisy.timer
:
