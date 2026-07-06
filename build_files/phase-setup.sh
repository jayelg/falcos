#!/bin/bash
# Runs before common/core and common/frequent — generic workarounds that
# persist across RUN layers as ordinary filesystem changes. Does NOT copy
# files/common (see Containerfile's comment above phase-finalize's mount for
# why — deferred to the last layer since nothing here reads it).
#
# Deliberately flavor-agnostic (no FLAVOR reference anywhere in this script
# or in the Containerfile instruction that runs it): common/core is 100%
# shared between the desktop and laptop builds, so this layer must produce
# an identical result for both, or its cache — and phase-core's — can never
# be shared across the two flavor builds. Flavor-specific files are copied
# in phase-flavor.sh instead, where flavor divergence is already expected.

set -ouex pipefail

# systemd-remount-fs.service is a static unit that always runs, trying to
# remount / per fstab options — composefs/overlay roots don't support this
# reconfigure and don't need it (ostree already handles read-only/writable
# split at boot), so it always fails with "overlay: No changes allowed in
# reconfigure". Cosmetic, but mask it rather than leave a spurious failure
# at every boot.
systemctl mask systemd-remount-fs.service

# Workaround for RPM packages that install to /opt (like mullvad-vpn).
# On ostree/bootc images, /opt is a symlink to var/opt, which causes cpio to fail.
mv /opt /opt.bak
mkdir /opt

# Workaround for RPM packages that try to start systemd services during install.
# We temporarily replace systemctl with a dummy command to prevent build failures.
# Restored in phase-finalize.sh, after common/core and common/frequent both run.
mv /usr/bin/systemctl /usr/bin/systemctl.bak
ln -s /usr/bin/true /usr/bin/systemctl
