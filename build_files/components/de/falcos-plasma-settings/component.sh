# falcos-plasma-settings — KDE System Settings integration for falcos.
# Currently the staged-bootc-update module + notifier, installed from the
# falcos-bootc-updates RPM. Runs after kde-desktop so its Plasma/KCM
# dependencies are already present (installing it earlier would drag Plasma
# into an early layer). The update *mechanism* it surfaces lives in the
# auto-updates component.
source /ctx/lib/fetch-helpers.sh
fetch_install_rpm \
    "https://github.com/jayelg/falcos-bootc-updates/releases/download/v${FALCOS_BOOTC_UPDATES_VERSION}/falcos-bootc-updates-${FALCOS_BOOTC_UPDATES_VERSION}-1.fc44.x86_64.rpm" \
    "$FALCOS_BOOTC_UPDATES_SHA256"
