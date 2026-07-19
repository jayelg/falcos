### Sudo hardening
COMPDIR="$(dirname "${BASH_SOURCE[0]}")"
COMPONENT_VERSION="${COMPONENT_VERSION:-latest}"
if [ -d "$COMPDIR/$COMPONENT_VERSION" ]; then
    COMPDIR="$COMPDIR/$COMPONENT_VERSION"
fi

install -Dm440 "$COMPDIR/files/etc/sudoers.d/99-hardening" /etc/sudoers.d/99-hardening
