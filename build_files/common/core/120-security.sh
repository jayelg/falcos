### Backup & security
SECURITY_PACKAGES=(
    borgbackup
    opensc               # smartcard middleware (PKCS#11/CCID)
    pam-u2f              # PAM module for FIDO U2F hardware keys
    pam_yubico           # PAM module for YubiKey OTP
    pamu2fcfg            # registers U2F keys for pam-u2f
    pcsc-lite            # smartcard daemon (pcscd)
    pcsc-lite-ccid       # CCID driver for pcscd (covers YubiKey/most smartcard readers)
    rclone
    restic
    solaar-udev          # udev rules for Logitech Unifying/Bolt receivers (Solaar)
    yubikey-manager
)
dnf5 install -y "${SECURITY_PACKAGES[@]}"
