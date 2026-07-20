### CLI utilities — traditional tools only; modern replacements (bat, eza,
### ripgrep, fd-find, ugrep, zoxide) and shell bling live in cli-customizations.
CLI_PACKAGES=(
    7zip-standalone
    bash-completion
    bc
    bsdunzip
    btop
    htop
    iw
    mtr
    pv
    rsync
    tmux
    tree
    vim-enhanced
    whois
    wl-clipboard
    zip
)
dnf5 install -y "${CLI_PACKAGES[@]}"
