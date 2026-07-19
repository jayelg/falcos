# Affinity v3 (Windows app) under patched Wine
# Phase: frequent
# Priority: 040
# Writable paths: /usr/bin /usr/lib/wine-affinity /usr/share/wine-affinity /usr/libexec/affinity-sync-prefix /usr/share/applications/affinity.desktop /usr/share/icons/hicolor/scalable/apps/affinity.svg /usr/lib/systemd/user/affinity-sync.service

COMPDIR="$(dirname "${BASH_SOURCE[0]}")"

# COMPONENT_VERSION is set by the Containerfile RUN instruction from COMPONENTS.list.
COMPONENT_VERSION="${COMPONENT_VERSION:-latest}"

# If a versioned subdirectory exists, switch into it.
if [ -d "$COMPDIR/$COMPONENT_VERSION" ]; then
    COMPDIR="$COMPDIR/$COMPONENT_VERSION"
fi

# Source version pins
source "$COMPDIR/versions.sh"

# winetricks drives the prefix setup; Wine's OpenCL passthrough goes through
# the base image's OpenCL-ICD-Loader with the rusticl ICD (mesa-libOpenCL,
# common/core/090); zstd for the vkd3d-proton tarball below.
# 7zip needed at runtime by falcos affinity-setup to extract the .NET 4.8
# offline installer's x64 MSI (bypassing the 32-bit self-extractor which
# fails on this WoW64-only Wine build).
dnf5 install -y winetricks clinfo zstd 7zip

### Patched Wine (WoW64 build, no 32-bit runtime needed)
curl --retry 3 -fsSLo /tmp/wine-affinity.tar.xz \
    "https://github.com/ryzendew/Affinity-Wine-Builder/releases/download/${AFFINITY_WINE_TAG}/ElementalWarrior-wine-${AFFINITY_WINE_TAG}.tar.xz"
echo "${AFFINITY_WINE_SHA256}  /tmp/wine-affinity.tar.xz" | sha256sum -c -
mkdir /tmp/wine-affinity
tar -xf /tmp/wine-affinity.tar.xz -C /tmp/wine-affinity
# Top-level directory name varies between releases; locate bin/wine and
# normalise whatever contains it to /usr/lib/wine-affinity.
WINE_BIN_DIR="$(find /tmp/wine-affinity -maxdepth 3 -type f -name wine -path '*/bin/*' -printf '%h\n' -quit)"
mv "$(dirname "$WINE_BIN_DIR")" /usr/lib/wine-affinity
rm -rf /tmp/wine-affinity /tmp/wine-affinity.tar.xz

### PE DXVK + vkd3d-proton DLLs, staged for affinity-setup to copy into the
### prefix (Fedora's dxvk-native is the Linux-native build, wrong artifact)
curl --retry 3 -fsSLo /tmp/dxvk.tar.gz \
    "https://github.com/doitsujin/dxvk/releases/download/v${DXVK_VERSION}/dxvk-${DXVK_VERSION}.tar.gz"
echo "${DXVK_SHA256}  /tmp/dxvk.tar.gz" | sha256sum -c -
tar -xf /tmp/dxvk.tar.gz -C /tmp
install -D -m 0644 -t /usr/share/wine-affinity/dxvk/x64 "/tmp/dxvk-${DXVK_VERSION}/x64/"*.dll
rm -rf "/tmp/dxvk-${DXVK_VERSION}" /tmp/dxvk.tar.gz

curl --retry 3 -fsSLo /tmp/vkd3d-proton.tar.zst \
    "https://github.com/HansKristian-Work/vkd3d-proton/releases/download/v${VKD3D_PROTON_VERSION}/vkd3d-proton-${VKD3D_PROTON_VERSION}.tar.zst"
echo "${VKD3D_PROTON_SHA256}  /tmp/vkd3d-proton.tar.zst" | sha256sum -c -
mkdir /tmp/vkd3d-proton
tar --use-compress-program=zstd -xf /tmp/vkd3d-proton.tar.zst -C /tmp/vkd3d-proton --strip-components=1
install -D -m 0644 -t /usr/share/wine-affinity/vkd3d-proton/x64 /tmp/vkd3d-proton/x64/*.dll
rm -rf /tmp/vkd3d-proton /tmp/vkd3d-proton.tar.zst

### WinRT metadata + wintypes shim, staged for affinity-setup
# One merged Windows.winmd serves every Windows.* namespace via WinRT's
# fallback probing; the shim is the pairing upstream
# Linux-Affinity-Installer uses.
curl --retry 3 -fsSLo /tmp/Windows.winmd \
    "https://github.com/microsoft/windows-rs/raw/${WINDOWS_WINMD_COMMIT}/crates/libs/bindgen/default/Windows.winmd"
echo "${WINDOWS_WINMD_SHA256}  /tmp/Windows.winmd" | sha256sum -c -
install -D -m 0644 /tmp/Windows.winmd /usr/share/wine-affinity/WinMetadata/Windows.winmd
rm -f /tmp/Windows.winmd

curl --retry 3 -fsSLo /tmp/wintypes_shim.dll.so \
    "https://github.com/ElementalWarrior/wine-wintypes.dll-for-affinity/raw/${WINTYPES_SHIM_COMMIT}/wintypes_shim.dll.so"
echo "${WINTYPES_SHIM_SHA256}  /tmp/wintypes_shim.dll.so" | sha256sum -c -
install -D -m 0644 /tmp/wintypes_shim.dll.so /usr/share/wine-affinity/wintypes.dll
rm -f /tmp/wintypes_shim.dll.so

### VC++ 2022 64-bit redistributable (winetricks' vcrun2022 verb uses the 32-bit
# regedit path which doesn't exist on this WoW64 Wine build)
curl --retry 3 -fsSLo /tmp/vc_redist.x64.exe \
    "https://aka.ms/vs/17/release/vc_redist.x64.exe"
# No official checksum published for the VC++ redist; trust-on-first-use like
# the Wine tarball. SHA256 is validated by checksums.yml on first bump.
echo "${VC_REDIST_X64_SHA256}  /tmp/vc_redist.x64.exe" | sha256sum -c -
install -D -m 0644 /tmp/vc_redist.x64.exe /usr/share/wine-affinity/vc_redist.x64.exe
rm -f /tmp/vc_redist.x64.exe

### .NET 4.8 offline installer (winetricks' dotnet48 verb calls dotnet40 which
# needs syswow64 (32-bit) support that this WoW64 Wine build lacks)
curl --retry 3 -fsSLo /tmp/ndp48-x86-x64-allos-enu.exe \
    "https://download.visualstudio.microsoft.com/download/pr/7afca223-55d2-470a-8edc-6a1739ae3252/abd170b4b0ec15ad0222a809b761a036/ndp48-x86-x64-allos-enu.exe"
echo "${DOTNET48_SHA256}  /tmp/ndp48-x86-x64-allos-enu.exe" | sha256sum -c -
install -D -m 0644 /tmp/ndp48-x86-x64-allos-enu.exe /usr/share/wine-affinity/ndp48-x86-x64-allos-enu.exe
rm -f /tmp/ndp48-x86-x64-allos-enu.exe

### Launcher
# env -u LD_PRELOAD: Wine crashes under the system-wide hardened_malloc
# preload (same class of exemption as codium/virt-manager).
# RUSTICL_ENABLE: rusticl exposes no OpenCL devices unless the Mesa driver
# is opted in; radeonsi covers the desktop iGPU, iris the laptop.
cat > /usr/bin/affinity <<'EOF'
#!/bin/bash
export WINEPREFIX="${AFFINITY_PREFIX:-$HOME/.local/share/affinity}"
AFFINITY_EXE="C:\\Program Files\\Affinity\\Affinity\\Affinity.exe"
if [ ! -f "$WINEPREFIX/drive_c/Program Files/Affinity/Affinity/Affinity.exe" ]; then
    msg="Affinity is not set up for this user yet. Run: falcos affinity-setup"
    command -v kdialog >/dev/null && kdialog --error "$msg" || echo "$msg" >&2
    exit 1
fi
exec env -u LD_PRELOAD RUSTICL_ENABLE=radeonsi,iris \
    /usr/lib/wine-affinity/bin/wine "$AFFINITY_EXE" "$@"
EOF
chmod 755 /usr/bin/affinity

# Install overlay files into the image
[ -d "$COMPDIR/files" ] && cp -rT "$COMPDIR/files" "/"

# Append runtime justfile recipes to the shared app-recipes file
if [ -f "$COMPDIR/justfile.inc" ]; then
    cat "$COMPDIR/justfile.inc" >> /usr/share/falcos/justfile.apps
fi
