# falcos-bootc-updates, System Settings module + notifier for staged bootc updates
# Phase: frequent
# Priority: 020 (after VPNs, before Affinity/Trivalent)
# Writable paths: /usr (dnf5-installed RPM)

COMPDIR="$(dirname "${BASH_SOURCE[0]}")"
COMPONENT_VERSION="${COMPONENT_VERSION:-latest}"
if [ -d "$COMPDIR/$COMPONENT_VERSION" ]; then
    COMPDIR="$COMPDIR/$COMPONENT_VERSION"
fi

source "$COMPDIR/versions.sh"

# Ships a user preset that enables its notifier
curl -fsSL --retry 3 -o /tmp/falcos-bootc-updates.rpm \
    "https://github.com/jayelg/falcos-bootc-updates/releases/download/v${FALCOS_BOOTC_UPDATES_VERSION}/falcos-bootc-updates-${FALCOS_BOOTC_UPDATES_VERSION}-1.fc44.x86_64.rpm"
echo "${FALCOS_BOOTC_UPDATES_SHA256}  /tmp/falcos-bootc-updates.rpm" | sha256sum -c -
dnf5 install -y /tmp/falcos-bootc-updates.rpm
rm -f /tmp/falcos-bootc-updates.rpm

[ -d "$COMPDIR/files" ] && cp -rT "$COMPDIR/files" "/"
if [ -f "$COMPDIR/justfile.inc" ]; then
    cat "$COMPDIR/justfile.inc" >> /usr/share/falcos/justfile.apps
fi
