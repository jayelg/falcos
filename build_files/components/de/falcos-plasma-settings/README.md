# falcos-plasma-settings

KDE System Settings integration for falcos. Currently the staged-bootc-update
module + notifier, installed from the checksum-verified `falcos-bootc-updates`
RPM. Runs after [kde-desktop](../kde-desktop) so its Plasma/KCM dependencies
are already present.

The update *mechanism* this surfaces (auto-update timer, sigstore policy)
lives in [core/auto-updates](../../core/auto-updates); the falcos-cli/`just`
framework lives in [core/falcos-tools](../../core/falcos-tools).

## Build

- Downloads the RPM from the GitHub release, verifies the SHA256, installs via dnf5.

## Runtime

The notifier runs as a user service; the module appears in KDE System Settings.
