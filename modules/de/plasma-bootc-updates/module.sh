# The staged-bootc-update panel for KDE System Settings and its notifier,
# installed from the falcos-bootc-updates RPM, which is the upstream
# package name. Runs after kde-desktop so its Plasma/KCM
# dependencies are already present (installing it earlier would drag Plasma
# into an early layer). The update *mechanism* it surfaces lives in the
# auto-updates module.
source /ctx/lib/fetch-helpers.sh
fetch_install_rpm "$ASSET_FALCOS_BOOTC_UPDATES_URL" "$ASSET_FALCOS_BOOTC_UPDATES_SHA256"
