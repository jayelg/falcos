### Own RPMs, installed via checksummed download rather than dnf5-by-URL:
### dnf5 doesn't GPG-check URL-installed RPMs and release tags are mutable.

### plasma-network-audio, own KDE module for AirPlay/RAOP network audio
curl -fsSL --retry 3 -o /tmp/plasma-network-audio.rpm \
    "https://github.com/johngrantdev/plasma-network-audio/releases/download/${PLASMA_NETWORK_AUDIO_TAG}/plasma-network-audio-0.1-0.alpha_1.fc44.x86_64.rpm"
echo "${PLASMA_NETWORK_AUDIO_SHA256}  /tmp/plasma-network-audio.rpm" | sha256sum -c -
dnf5 install -y /tmp/plasma-network-audio.rpm
rm -f /tmp/plasma-network-audio.rpm

### falcos-bootc-updates, own System Settings module + notifier for staged
### bootc image updates, ships a user preset that enables its notifier
curl -fsSL --retry 3 -o /tmp/falcos-bootc-updates.rpm \
    "https://github.com/jayelg/falcos-bootc-updates/releases/download/v${FALCOS_BOOTC_UPDATES_VERSION}/falcos-bootc-updates-${FALCOS_BOOTC_UPDATES_VERSION}-1.fc44.x86_64.rpm"
echo "${FALCOS_BOOTC_UPDATES_SHA256}  /tmp/falcos-bootc-updates.rpm" | sha256sum -c -
dnf5 install -y /tmp/falcos-bootc-updates.rpm
rm -f /tmp/falcos-bootc-updates.rpm
