### KDE Theming
dnf5 install -y \
    papirus-icon-theme \
    plasma-wallpapers-dynamic \
    plasma-wallpapers-dynamic-builder

### Darkly — Qt widget style + KWin window decoration
DARKLY_BUILD_DEPS=(
    cmake gcc-c++ extra-cmake-modules
    qt6-qtbase-devel
    kf6-frameworkintegration-devel
    kf6-kguiaddons-devel
    kf6-ki18n-devel
    kf6-kcmutils-devel
    kf6-kirigami-devel
    kf6-kwindowsystem-devel
    kdecoration-devel
)
dnf5 install -y "${DARKLY_BUILD_DEPS[@]}"
curl -fsSL "https://github.com/Bali10050/Darkly/archive/refs/tags/v${DARKLY_VERSION}.tar.gz" \
    -o /tmp/darkly.tar.gz
tar -xzf /tmp/darkly.tar.gz -C /tmp/
cmake \
    -B /tmp/darkly-build \
    -S "/tmp/Darkly-${DARKLY_VERSION}" \
    -DBUILD_TESTING=OFF \
    -Wno-dev \
    -DKDE_INSTALL_USE_QT_SYS_PATHS=ON \
    -DBUILD_QT6=ON \
    -DBUILD_QT5=OFF
cmake --build /tmp/darkly-build -j "$(nproc)"
cmake --install /tmp/darkly-build
rm -rf /tmp/darkly.tar.gz "/tmp/Darkly-${DARKLY_VERSION}" /tmp/darkly-build
dnf5 remove -y --noautoremove "${DARKLY_BUILD_DEPS[@]}"

# Ant-Dark plasma desktop theme (github.com/EliverLara/Ant). ANT_COMMIT
# pinned in build_files/versions-core-theming.sh.
curl -fsSL "https://github.com/EliverLara/Ant/archive/${ANT_COMMIT}.tar.gz" \
    -o /tmp/ant.tar.gz
tar -xzf /tmp/ant.tar.gz -C /tmp/
cp -r "/tmp/Ant-${ANT_COMMIT}/kde/Dark/plasma/desktoptheme/Ant-Dark" \
    /usr/share/plasma/desktoptheme/Ant-Dark
rm -rf /tmp/ant.tar.gz "/tmp/Ant-${ANT_COMMIT}"

# Advanced Weather Widget
curl -fsSL "https://github.com/pnedyalkov91/advanced-weather-widget/releases/download/${AWW_VERSION}/advanced-weather-widget.plasmoid" \
    -o /tmp/weather-widget.plasmoid
mkdir -p /usr/share/plasma/plasmoids/org.kde.plasma.advanced-weather-widget
unzip /tmp/weather-widget.plasmoid -d /usr/share/plasma/plasmoids/org.kde.plasma.advanced-weather-widget/
rm /tmp/weather-widget.plasmoid
