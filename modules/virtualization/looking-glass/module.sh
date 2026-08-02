### Looking Glass: the kvmfr kernel module (shared-memory transport between
### host and VM) and the client that displays the guest's frames.
# Desktop flavor only (gated in the image): pairs with
# the VFIO GPU-passthrough setup in the vfio-passthrough module.
source /ctx/lib/dkms-helpers.sh
kernel_devel_install "${DKMS_BUILD_DEPS[@]}"

# --recurse-submodules for the client: the kernel module builds without
# them, the client does not.
git clone --quiet --depth 1 --recurse-submodules --shallow-submodules \
    --branch "$ASSET_LOOKING_GLASS_VERSION" \
    https://github.com/gnif/LookingGlass.git /tmp/looking-glass

# Version comes from upstream's dkms.conf at the pinned tag, no manual
# pin to keep in sync
KVMFR_VERSION="$(dkms_conf_version /tmp/looking-glass/module)"

dkms_build_module kvmfr "$KVMFR_VERSION" /tmp/looking-glass/module

### The client, built from the same tree at the same tag
# Nobody packages it: it is not in Fedora or RPM Fusion, upstream ships
# source only, and the third-party COPRs that carry it are personal. The
# source is already here for kvmfr, so building it is one cmake run, and
# the client and the kernel module cannot end up on different releases.
#
# Upstream's dependency list is for Debian. Two entries here have no
# counterpart in it: libXrandr-devel, because Fedora's libXpresent-devel
# does not pull it in and Xpresent.h includes Xrandr.h, and libzstd-devel,
# for the link below. pkg-config is deliberately absent: the base ships it
# and kmod depends on it, so it can be neither installed nor removed here.
LOOKING_GLASS_BUILD_DEPS=(
    cmake gcc-c++ binutils-devel
    fontconfig-devel gmp-devel nettle-devel spice-protocol libzstd-devel
    mesa-libEGL-devel mesa-libGL-devel libglvnd-devel
    libX11-devel libXfixes-devel libXi-devel libXinerama-devel
    libXScrnSaver-devel libXcursor-devel libXpresent-devel libXrandr-devel
    libxkbcommon-devel wayland-devel wayland-protocols-devel
    pipewire-devel libsamplerate-devel pulseaudio-libs-devel
)
dnf5 install -y "${LOOKING_GLASS_BUILD_DEPS[@]}"
# Two flags upstream does not need and this build does, both from being
# newer than B7's release:
#
# - Fedora 44 builds with GCC 16, which reports a maybe-uninitialized in
#   the vendored nanosvg header, and the client's CMakeLists hardcodes
#   -Werror with no option to turn it off. The specific -Wno-error= form
#   is what works: GCC gives the narrower option priority whatever the
#   order, while a bare -Wno-error loses to the -Werror added after it.
# - Fedora's static libbfd needs zstd, which the client's backtrace
#   support links without. Disabling backtraces (-DENABLE_BACKTRACE=no)
#   is the other way out and costs the backtrace on a crash.
#
# /usr, not the default /usr/local, which is a symlink into /var on a
# bootc image: image content has to land in /usr.
cmake -S /tmp/looking-glass/client -B /tmp/looking-glass-build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_C_FLAGS=-Wno-error=maybe-uninitialized \
    -DCMAKE_EXE_LINKER_FLAGS=-lzstd \
    -Wno-dev
cmake --build /tmp/looking-glass-build -j "$(nproc)"
cmake --install /tmp/looking-glass-build
rm -rf /tmp/looking-glass-build
# --noautoremove, like Darkly in de/kde-theming: the headers go and the
# runtime libraries they pulled in stay, because they are what the client
# links against. Plain removal would take libsamplerate, which nothing
# else in the image requires and the client's audio backend needs, and
# the image would ship a client that cannot start. gcc and make belong to
# the DKMS list and go with kernel_devel_remove below.
dnf5 remove -y --noautoremove "${LOOKING_GLASS_BUILD_DEPS[@]}"

kernel_devel_remove "${DKMS_BUILD_DEPS_REMOVE[@]}"
rm -rf /tmp/looking-glass
