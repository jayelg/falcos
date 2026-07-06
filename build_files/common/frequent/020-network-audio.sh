### plasma-network-audio — KDE module for managing AirPlay/RAOP network audio
# devices. Own project, actively developed, so it lives here rather than
# alongside the stable multimedia packages in common/core/090-multimedia.sh.
# PLASMA_NETWORK_AUDIO_TAG pinned in build_files/versions-frequent-network.sh.
dnf5 install -y "https://github.com/johngrantdev/plasma-network-audio/releases/download/${PLASMA_NETWORK_AUDIO_TAG}/plasma-network-audio-0.1-0.alpha_1.fc44.x86_64.rpm"
