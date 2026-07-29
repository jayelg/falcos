# goojust

The essential tools for managing the live image.

Related modules: the OS self-update + signing *mechanism* lives in
[auto-updates](../auto-updates); the bootc-updates KDE System Settings GUI
lives in [de/falcos-plasma-settings](../../de/falcos-plasma-settings).

## goojust
the `goojust` OS TUI for running the justfiles

### Build

- `dnf5 install just fastfetch` dependency required by goojust
- Downloads + SHA256-verifies the goojust release and runs its install.sh. 
This adds the executable tool and the runtime helper `goojust-helpers.sh` into the image.
- Passed `--no-config`: goojust's installer would otherwise seed a starter
  `config.toml`, and we ship our own below. `run-module.sh` copies `files/`
  after `module.sh`, so our overlay would win regardless, but skipping the
  seed keeps the justfile path ours rather than the installer's default.

## Files

- `etc/profile.d/goojust.sh` — aliases the OS name (lowercased) to `goojust`
- `usr/share/goojust/config.toml` — points goojust at our justfile. goojust
  has no built-in justfile location and exits with an error without this, so
  the path is ours to declare rather than one inherited from the tool. Under
  `/usr` on purpose: a locally-modified `/etc` file is frozen by ostree's
  config merge and would pin an old path across image updates.
- `usr/share/goojust/justfile` — the system justfile, referenced by the
  config above. Imports `justfile.apps`, which `run-module.sh` builds at
  build time from each module's `justfile.inc`, plus an optional
  `~/.config/just/user.justfile` for personal recipes.
