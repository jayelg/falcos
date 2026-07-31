### KDE Theming
source /ctx/lib/fetch-helpers.sh

### Darkly Qt widget style + KWin window decoration, built from source
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
fetch_extract "$ASSET_DARKLY_URL" "$ASSET_DARKLY_SHA256" /tmp
cmake \
    -B /tmp/darkly-build \
    -S "/tmp/Darkly-${ASSET_DARKLY_VERSION}" \
    -DBUILD_TESTING=OFF \
    -Wno-dev \
    -DKDE_INSTALL_USE_QT_SYS_PATHS=ON \
    -DBUILD_QT6=ON \
    -DBUILD_QT5=OFF
cmake --build /tmp/darkly-build -j "$(nproc)"
cmake --install /tmp/darkly-build
rm -rf "/tmp/Darkly-${ASSET_DARKLY_VERSION}" /tmp/darkly-build
dnf5 remove -y --noautoremove "${DARKLY_BUILD_DEPS[@]}"

# Ant-Dark plasma desktop theme
fetch_extract "$ASSET_ANT_URL" "$ASSET_ANT_SHA256" /tmp
cp -r "/tmp/Ant-${ASSET_ANT_VERSION}/kde/Dark/plasma/desktoptheme/Ant-Dark" \
    /usr/share/plasma/desktoptheme/Ant-Dark
rm -rf "/tmp/Ant-${ASSET_ANT_VERSION}"

# Advanced Weather Widget
fetch_extract "$ASSET_ADVANCED_WEATHER_WIDGET_URL" "$ASSET_ADVANCED_WEATHER_WIDGET_SHA256" \
    /usr/share/plasma/plasmoids/org.kde.plasma.advanced-weather-widget
