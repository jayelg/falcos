### Codec/driver overrides (negativo17)
OVERRIDES=(
    intel-gmmlib
    intel-mediasdk
    intel-vpl-gpu-rt          # Intel Video Processing Library GPU runtime
    libheif
    libva
    libva-intel-media-driver
    mesa-dri-drivers
    mesa-filesystem
    mesa-libEGL
    mesa-libGL
    mesa-libgbm
    mesa-vulkan-drivers
)
dnf5 distro-sync --skip-unavailable -y --repo='fedora-multimedia' "${OVERRIDES[@]}"
dnf5 versionlock add "${OVERRIDES[@]}"
MULTIMEDIA_PACKAGES=(
    ffmpeg
    ffmpeg-libs
    libva-utils
    pipewire-config-raop      # AirPlay/RAOP network audio support, see below
    pipewire-gstreamer        # lets GStreamer apps route audio through PipeWire
    pipewire-libs-extra       # extra codec/format plugins (e.g. AAC, LDAC)
    pipewire-utils
)
dnf5 install -y "${MULTIMEDIA_PACKAGES[@]}"

# plasma-network-audio (own project, actively developed — see
# common/frequent/020-network-audio.sh) is installed in the frequent layer.
# disable raop-discover auto-sink creation
# Removes the symlink that enables libpipewire-module-raop-discover, which
# auto-creates audio sinks for any AirPlay/RAOP device on the network.
# libpipewire-module-raop-sink remains available for explicit connections.
rm -f /usr/share/pipewire/pipewire.conf.d/50-raop.conf
