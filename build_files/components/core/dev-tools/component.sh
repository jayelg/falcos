### Dev tools
DEV_PACKAGES=(
    direnv
    git
    git-credential-libsecret
    git-delta
    git-lfs
    gum
    just
)
dnf5 install -y "${DEV_PACKAGES[@]}"
