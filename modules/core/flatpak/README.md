# flatpak

Flatpak client plus a first-boot default-app install and a daily system
update timer.

## Build

- `dnf5 install flatpak` -- the fedora-bootc base does not guarantee it.

## Files

- `install-flatpaks.service` + `usr/libexec/install-flatpaks` -- first-boot Flathub remote add, then installs every flatpak listed in `/usr/share/flatpak-defaults/apps.list` (aggregated at build time from each module's `flatpaks.list` by `run-module.sh`).
- `flatpak-update.{timer,service}` -- daily `flatpak update --system`
- `45-module-flatpak.preset` -- enables both units

## Adding default flatpaks

Add a `flatpaks.list` file to the module directory (one flatpak ID per line, `#` comments and blank lines ignored). At build time `run-module.sh` concatenates it into `/usr/share/flatpak-defaults/apps.list`; the first-boot service installs each one.
