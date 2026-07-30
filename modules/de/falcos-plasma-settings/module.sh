# falcos-plasma-settings — KDE System Settings integration for falcos.
# Currently the staged-bootc-update module + notifier, installed from the
# falcos-bootc-updates RPM. Runs after kde-desktop so its Plasma/KCM
# dependencies are already present (installing it earlier would drag Plasma
# into an early layer). The update *mechanism* it surfaces lives in the
# auto-updates module.
source /ctx/lib/fetch-helpers.sh
fetch_install_rpm "$ASSET_FALCOS_BOOTC_UPDATES_URL" "$ASSET_FALCOS_BOOTC_UPDATES_SHA256"
