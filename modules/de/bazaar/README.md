# bazaar

Bazaar software center (Flatpak).

## Build

Pure-file module: no build-time install logic. The `flatpaks.list` is
aggregated into `/usr/share/falcos/default-flatpaks` by `run-module.sh`
and installed at first boot by the `flatpak` module's
`install-flatpaks` service.
