### VSCodium
# Repo is configured (disabled) by this component's repo file; enable it
# just for this install.
dnf5 install -y --enablerepo='vscodium' codium

# Electron crashes under the system-wide hardened_malloc LD_PRELOAD, wrap
# the binary to drop it.
source /ctx/lib/wrap-helpers.sh
wrap_no_hardened_malloc /usr/share/codium/codium
