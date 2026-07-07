### CLI utilities
CLI_PACKAGES=(
    7zip-standalone
    bat
    bc                     # POSIX calculator, used by some shell scripts
    bsdunzip               # BSD unzip, handles some archives GNU unzip chokes on
    btop
    chezmoi                # dotfiles manager
    eza
    fastfetch              # neofetch-style system info banner
    fd-find                # faster find alternative (binary is `fd`)
    htop
    iw                     # wireless device config/inspection
    mtr                    # combined traceroute + ping
    pv                     # progress bar for piped data
    ripgrep
    rsync
    tmux
    tree
    ugrep                  # grep alternative used for the `ug`/`grep` alias
    vim-enhanced
    whois
    wl-clipboard           # Wayland clipboard CLI (xclip equivalent)
    zip
    zoxide                 # smarter `cd` that learns frequent directories
)
dnf5 install -y "${CLI_PACKAGES[@]}"
