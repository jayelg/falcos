# brew

Homebrew (Linuxbrew) first-login setup. Pure-file component; the install
runs on the user's first login, not at image build.

## Files

- `usr/libexec/brew-setup` -- pinned-commit, checksum-verified Homebrew installer
- `usr/lib/systemd/user/brew-setup.service` -- runs it once per user (guarded by `~/.brew-setup-done`)
- `etc/profile.d/linuxbrew.sh` -- `brew shellenv`, with Homebrew's bin/sbin moved to the end of PATH so it never shadows system tools
- `45-falcos-brew.preset` (user) -- enables `brew-setup.service`
