### plasma-network-audio, own KDE module for AirPlay/RAOP network audio
dnf5 install -y "https://github.com/johngrantdev/plasma-network-audio/releases/download/${PLASMA_NETWORK_AUDIO_TAG}/plasma-network-audio-0.1-0.alpha_1.fc44.x86_64.rpm"

### falcos-bootc-updates, own System Settings module + notifier for staged
### bootc image updates, ships a user preset that enables its notifier
dnf5 install -y "https://github.com/jayelg/falcos-bootc-updates/releases/download/${FALCOS_BOOTC_UPDATES_TAG}/falcos-bootc-updates-${FALCOS_BOOTC_UPDATES_TAG#v}-1.fc44.x86_64.rpm"
