# Netbird mesh VPN
# Phase: frequent
# Priority: 010 (early, VPN daemons)
# Writable paths: /usr (dnf5-installed packages)

COMPDIR="$(dirname "${BASH_SOURCE[0]}")"
COMPONENT_VERSION="${COMPONENT_VERSION:-latest}"
if [ -d "$COMPDIR/$COMPONENT_VERSION" ]; then
    COMPDIR="$COMPDIR/$COMPONENT_VERSION"
fi

dnf5 install -y netbird

[ -d "$COMPDIR/files" ] && cp -rT "$COMPDIR/files" "/"
if [ -f "$COMPDIR/justfile.inc" ]; then
    cat "$COMPDIR/justfile.inc" >> /usr/share/falcos/justfile.apps
fi
