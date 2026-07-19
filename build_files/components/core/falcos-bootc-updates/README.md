# falcos-bootc-updates

System Settings module and notifier for staged bootc image updates. Ships
a user preset that enables its notifier. Installed from a checksum-verified
RPM download at build time.

## Build

At image build time:
- Downloads the RPM from the GitHub release, verifies the SHA256, installs via dnf5.

## Files installed

- falcos-bootc-updates RPM packages
- User systemd preset for the update notifier

## Runtime

The notifier runs as a user service. Check status in System Settings.
