### Dev tools
DEV_PACKAGES=(
    direnv                         # per-directory environment variables
    git
    git-credential-libsecret       # store git credentials in the system keyring
    git-delta                      # syntax-highlighted git diffs
    git-lfs
    gum                            # TUI prompt library used by shell scripts
    just
)
dnf5 install -y "${DEV_PACKAGES[@]}"

# No sudoers secure_path entry for linuxbrew: /home/linuxbrew is
# user-writable, so putting it in root's PATH would let user-level code
# plant a binary that `sudo <name>` runs as root.
