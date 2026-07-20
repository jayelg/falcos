# flatpak

Flatpak client plus a first-boot default-app install and a daily system
update timer.

## Build

- `dnf5 install flatpak` -- the fedora-bootc base does not guarantee it.

## Files

- `install-default-flatpaks.service` + `usr/libexec/install-default-flatpaks` -- first-boot Flathub remote + default apps (Bazaar, Bitwarden)
- `flatpak-update.{timer,service}` -- daily `flatpak update --system`
- `45-falcos-flatpak.preset` -- enables both units
