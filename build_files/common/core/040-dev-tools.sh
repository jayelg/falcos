### Dev tools
DEV_PACKAGES=(
    chezmoi                        # dotfiles manager
    direnv                         # per-directory environment variables
    git
    git-credential-libsecret       # store git credentials in the system keyring
    git-delta                      # syntax-highlighted git diffs
    git-lfs
    gum                            # TUI prompt library used by shell scripts
    just
)
dnf5 install -y "${DEV_PACKAGES[@]}"

# Keep linuxbrew reachable under sudo, which resets PATH to secure_path.
# 0440 explicitly — sudo ignores drop-ins with looser modes.
install -Dm440 /dev/stdin /etc/sudoers.d/10-linuxbrew-path <<'EOF'
Defaults secure_path = /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/linuxbrew/.linuxbrew/bin
EOF
