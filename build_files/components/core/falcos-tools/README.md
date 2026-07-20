# falcos-tools

The essential falcos CLI framework: the `falcos-cli` OS TUI and the `just`
engine behind the component `justfile.inc` recipe mechanism. Deliberately
KDE-independent, so it can sit early in [COMPONENTS.list](../../../../COMPONENTS.list)
as part of a minimal build.

Related components: the OS self-update + signing *mechanism* lives in
[auto-updates](../auto-updates); the bootc-updates KDE System Settings GUI
lives in [de/falcos-plasma-settings](../../de/falcos-plasma-settings).

## Build

- `dnf5 install just fastfetch` -- framework runtime deps installed here (not
  in cli-tools/dev-tools) so a minimal base+falcos-tools build stays
  self-contained: `just` drives the justfile.inc mechanism, `fastfetch` backs
  the TUI system panel.
- Downloads + SHA256-verifies the falcos-cli release and runs its install.sh
  (also drops the runtime helper `falcos-helpers.sh`).

## Files

- `etc/profile.d/falcos-cli.sh` -- aliases the OS name (lowercased) to `falcos-cli`
- `usr/libexec/falcos-progress`, `usr/share/falcos/justfile` -- CLI runtime helpers
