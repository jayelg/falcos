# cli-customizations

Opinionated shell UX, kept separate from the traditional-utilities
`cli-tools`. Modern replacements for the default coreutils (aliased over
cat/ls/grep/cd in `files/etc/profile.d/zz-bling.sh`), a fancier prompt and
readline, an AI CLI, and Nerd Fonts.

**dnf packages:** bat, eza, fd-find, gum, ripgrep, ugrep, zoxide

**Fetched + checksum-verified:** aichat, starship, flyline (Bash readline
replacement), Nerd Fonts

**Files:** `etc/profile.d/zz-bling.sh` — aliases (`ls`→eza, `cat`→bat,
`grep`→ugrep), plus direnv/zoxide hooks and the flyline readline enable, all
guarded by `command -v` so they no-op when a tool is absent.
