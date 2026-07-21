#!/bin/bash
# Pre-install workarounds. Flavor agnostic so the core layer cache is
# shared between the desktop and laptop builds.

set -ouex pipefail

# systemd-remount-fs always fails to reconfigure a composefs/overlay root.
# Cosmetic but noisy, mask it.
systemctl mask systemd-remount-fs.service

# On bootc images /opt is a symlink to var/opt, which breaks RPMs that
# install to /opt (e.g. mullvad-vpn). Restored in 99-finalize.sh.
mv /opt /opt.bak
mkdir /opt

# Stub out systemctl so package scriptlets can't start services mid-build.
# Restored in 99-finalize.sh.
mv /usr/bin/systemctl /usr/bin/systemctl.bak
ln -s /usr/bin/true /usr/bin/systemctl

# dnf5 copr/config-manager plugins, needed by the component repo files
# sourced in lib/run-component.sh.
dnf5 install -y dnf5-plugins
