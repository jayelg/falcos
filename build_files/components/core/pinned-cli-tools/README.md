# Pinned CLI Tools

Metapackage component that installs several individually-pinned CLI tools:
VSCodium, Bitwarden CLI, aichat, Starship, Flyline, falcos-cli, and Nerd Fonts.

Each tool is version-pinned with a checksum in versions.sh. VSCodium gets a
hardened_malloc exemption wrapper. This is a metapackage rather than
individual components because the tools are small and share the same build
phase; splitting them into separate components would add ~7 RUN layers for
minimal cache benefit.

## Build

At image build time:
- `dnf5 install -y --enablerepo='vscodium' codium` (with hardened_malloc wrapper)
- Downloads and verifies each tool binary from GitHub releases
- Installs to `/usr/bin/`, `/usr/share/fonts/`, etc.

## Files installed

- `/usr/share/codium/codium` (wrapped)
- `/usr/bin/bw`, `/usr/bin/aichat`, `/usr/bin/starship`, `/usr/bin/falcos-cli`
- `/usr/lib/bash/libflyline.so`
- `/usr/share/fonts/nerd-fonts/`
- `/usr/libexec/falcos-progress`, `/usr/share/falcos/falcos-helpers.sh`

## Runtime

No user setup required. `falcos-cli` is aliased to the OS name via
`etc/profile.d/falcos-cli.sh`. Starship is configured in the user's dotfiles.
