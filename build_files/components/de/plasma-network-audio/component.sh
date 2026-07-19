# plasma-network-audio, KDE module for AirPlay/RAOP network audio
# Phase: frequent
# Priority: 020 (after VPNs, before Affinity/Trivalent)
# Writable paths: /usr (dnf5-installed RPM)

COMPDIR="$(dirname "${BASH_SOURCE[0]}")"
COMPONENT_VERSION="${COMPONENT_VERSION:-latest}"
if [ -d "$COMPDIR/$COMPONENT_VERSION" ]; then
    COMPDIR="$COMPDIR/$COMPONENT_VERSION"
fi

source "$COMPDIR/versions.sh"

curl -fsSL --retry 3 -o /tmp/plasma-network-audio.rpm \
    "https://github.com/johngrantdev/plasma-network-audio/releases/download/${PLASMA_NETWORK_AUDIO_TAG}/plasma-network-audio-0.1-0.alpha_1.fc44.x86_64.rpm"
echo "${PLASMA_NETWORK_AUDIO_SHA256}  /tmp/plasma-network-audio.rpm" | sha256sum -c -
dnf5 install -y /tmp/plasma-network-audio.rpm
rm -f /tmp/plasma-network-audio.rpm

[ -d "$COMPDIR/files" ] && cp -rT "$COMPDIR/files" "/"
if [ -f "$COMPDIR/justfile.inc" ]; then
    cat "$COMPDIR/justfile.inc" >> /usr/share/falcos/justfile.apps
fi
