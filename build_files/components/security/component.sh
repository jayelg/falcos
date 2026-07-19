### Backup & security tools
SECURITY_PACKAGES=(
    borgbackup
    opensc
    pam-u2f
    pam_yubico
    pamu2fcfg
    pcsc-lite
    pcsc-lite-ccid
    rclone
    restic
    solaar-udev
    yubikey-manager
)
dnf5 install -y "${SECURITY_PACKAGES[@]}"
