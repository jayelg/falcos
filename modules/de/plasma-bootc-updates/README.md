# plasma-bootc-updates

The staged-bootc-update panel for KDE System Settings, plus its notifier,
installed from the checksum-verified `falcos-bootc-updates` RPM. Runs after
[kde-desktop](../kde-desktop) so its Plasma/KCM dependencies are already
present.

The update *mechanism* this surfaces (auto-update timer, sigstore policy)
lives in [core/auto-updates](../../core/auto-updates); the goojust/`just`
framework lives in [core/goojust](../../core/goojust).

## Build

- Downloads the RPM from the GitHub release, verifies the SHA256, installs via dnf5.

## Runtime

The notifier runs as a user service; the module appears in KDE System Settings.
