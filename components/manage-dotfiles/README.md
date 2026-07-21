# manage-dotfiles

New-machine user setup: dotfiles via chezmoi and secrets via the Bitwarden
CLI (against a self-hosted Vaultwarden). The interactive flow ships as the
`setup-dotfiles` recipe (justfile.inc), surfaced in falcos-cli under the
Configuration group.

## Build

- `dnf5 install chezmoi jq` -- chezmoi applies dotfiles; jq parses `bw status`.
- Downloads + SHA256-verifies the Bitwarden CLI (`bw`) binary.

## Recipe

`setup-dotfiles` (run once on a new machine): authenticates `bw` against a
Vaultwarden URL, provisions a GitHub SSH key, then `chezmoi init --apply`.
