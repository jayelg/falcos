# bitwarden

Bitwarden password manager (Flatpak).

## Build

Pure-file component: no build-time install logic. The `flatpaks.list` is
aggregated into `/usr/share/falcos/default-flatpaks` by `run-component.sh`
and installed at first boot by the `flatpak` component's
`install-flatpaks` service.
