# falcos-tools

The essential tools for managing the live image.

Related components: the OS self-update + signing *mechanism* lives in
[auto-updates](../auto-updates); the bootc-updates KDE System Settings GUI
lives in [de/falcos-plasma-settings](../../de/falcos-plasma-settings).

## goojust
the `goojust` OS TUI for running the justfiles

### Build

- `dnf5 install just fastfetch` dependency required by goojust
- Downloads + SHA256-verifies the goojust release and runs its install.sh. 
This adds the executable tool and the runtime helper `goojust-helpers.sh` into the image.

## Files

- `etc/profile.d/goojust.sh` — aliases the OS name (lowercased) to `goojust`
