# vscodium

VSCodium -- the telemetry-free, freely-licensed build of VS Code.

## Build

- Adds the VSCodium repo (disabled by default) via the `repo` file, then
  installs `codium` with the repo enabled just for this layer.
- Electron crashes under the system-wide hardened_malloc `LD_PRELOAD`, so the
  binary is wrapped to drop it (`wrap_no_hardened_malloc`).
