# falcos-bootc-updates, System Settings module + notifier for staged bootc
# updates. Ships a user preset that enables its notifier.
source /ctx/lib/fetch-helpers.sh
fetch_install_rpm \
    "https://github.com/jayelg/falcos-bootc-updates/releases/download/v${FALCOS_BOOTC_UPDATES_VERSION}/falcos-bootc-updates-${FALCOS_BOOTC_UPDATES_VERSION}-1.fc44.x86_64.rpm" \
    "$FALCOS_BOOTC_UPDATES_SHA256"
