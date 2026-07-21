# flatpak

Flatpak client plus a first-boot default-app install and a daily system
update timer.

## Build

- `dnf5 install flatpak` -- the fedora-bootc base does not guarantee it.

## Files

- `install-flatpaks.service` + `usr/libexec/install-flatpaks` -- first-boot Flathub remote add, then installs every flatpak listed in `/usr/share/falcos/default-flatpaks` (aggregated at build time from each component's `flatpaks.list` by `run-component.sh`).
- `flatpak-update.{timer,service}` -- daily `flatpak update --system`
- `45-falcos-flatpak.preset` -- enables both units

## Adding default flatpaks

Add a `flatpaks.list` file to the component directory (one flatpak ID per line, `#` comments and blank lines ignored). At build time `run-component.sh` concatenates it into `/usr/share/falcos/default-flatpaks`; the first-boot service installs each one.
