### CLI utilities
CLI_PACKAGES=(
    7zip-standalone
    bash-completion
    bat
    bc
    bsdunzip
    btop
    chezmoi
    eza
    fastfetch
    fd-find
    htop
    iw
    mtr
    pv
    ripgrep
    rsync
    tmux
    tree
    ugrep
    vim-enhanced
    whois
    wl-clipboard
    zip
    zoxide
)
dnf5 install -y "${CLI_PACKAGES[@]}"
