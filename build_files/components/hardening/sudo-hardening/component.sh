### Sudo hardening
# Installed by hand rather than via a files/ overlay so the sudoers file
# gets the 0440 mode sudo expects.
install -Dm440 "$COMPDIR/sudoers-hardening" /etc/sudoers.d/99-hardening
