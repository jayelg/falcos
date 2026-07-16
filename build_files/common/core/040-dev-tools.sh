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

# Deliberately no sudoers secure_path entry for linuxbrew:
# /home/linuxbrew/.linuxbrew/bin is user-writable, so putting it in root's
# PATH lets code running as the user stage a binary that a later
# `sudo <name>` executes as root. Use the full path for brew tools under
# sudo instead.
