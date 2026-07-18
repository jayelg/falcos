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

# rusticl OpenCL ICD (used by the Affinity Wine wrapper via RUSTICL_ENABLE).
# Not in OVERRIDES: distro-sync only syncs installed packages. Repo priority
# keeps it on fedora-multimedia; arch pinned so dnf can't pick the i686
# multilib package.
dnf5 install -y mesa-libOpenCL.x86_64
dnf5 versionlock add mesa-libOpenCL
MULTIMEDIA_PACKAGES=(
    ffmpeg
    ffmpeg-libs
    libva-utils
    pipewire-config-raop      # AirPlay/RAOP network audio support
    pipewire-gstreamer        # lets GStreamer apps route audio through PipeWire
    pipewire-libs-extra       # extra codec/format plugins (e.g. AAC, LDAC)
    pipewire-utils
)
dnf5 install -y "${MULTIMEDIA_PACKAGES[@]}"

# Disable raop-discover auto-sink creation for every AirPlay device on the
# network; raop-sink remains available for explicit connections.
rm -f /usr/share/pipewire/pipewire.conf.d/50-raop.conf
