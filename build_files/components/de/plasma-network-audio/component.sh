# plasma-network-audio, KDE module for AirPlay/RAOP network audio
source /ctx/lib/fetch-helpers.sh
fetch_install_rpm \
    "https://github.com/johngrantdev/plasma-network-audio/releases/download/${PLASMA_NETWORK_AUDIO_TAG}/plasma-network-audio-0.1-0.alpha_1.fc44.x86_64.rpm" \
    "$PLASMA_NETWORK_AUDIO_SHA256"
