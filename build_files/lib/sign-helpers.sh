#!/bin/bash
# Secure Boot (MOK) signing helpers, sourced by scripts that build a kernel
# or DKMS module. Signing is optional: without a build secret, callers skip it.

MOK_KEY="/run/secrets/mok_privkey"
MOK_CERT_DER="/usr/share/falcos/sb_cert.der"

mok_signing_available() {
    [ -s "$MOK_KEY" ] && [ -f "$MOK_CERT_DER" ]
}

# Point DKMS at this repo's key instead of the throwaway one it would
# otherwise generate and bake into the image. With no key present both
# paths are unwritable, so DKMS fails cleanly.
configure_dkms_signing() {
    if mok_signing_available; then
        export mok_signing_key="$MOK_KEY"
        export mok_certificate="$MOK_CERT_DER"
    else
        export mok_signing_key="/run/secrets/mok_privkey"
        export mok_certificate="/run/secrets/mok_privkey.pub"
    fi
}

# <module-path> <sign-file-path>. Handles .ko/.ko.xz/.ko.zst.
sign_kernel_module() {
    local ko="$1" sign_file="$2" bare
    case "$ko" in
        *.ko.xz)
            bare="${ko%.xz}"
            xz -dk "$ko"
            "$sign_file" sha256 "$MOK_KEY" "$MOK_CERT_DER" "$bare"
            xz -f "$bare"
            ;;
        *.ko.zst)
            bare="${ko%.zst}"
            zstd -dq "$ko" -o "$bare"
            "$sign_file" sha256 "$MOK_KEY" "$MOK_CERT_DER" "$bare"
            zstd -qf "$bare" -o "$ko"
            rm -f "$bare"
            ;;
        *.ko)
            "$sign_file" sha256 "$MOK_KEY" "$MOK_CERT_DER" "$ko"
            ;;
    esac
}

# Signs every module under <dir>.
sign_modules_under() {
    local dir="$1" sign_file="$2"
    [ -d "$dir" ] || return 0
    while IFS= read -r ko; do
        sign_kernel_module "$ko" "$sign_file"
        echo "  Signed: $(basename "$ko")"
    done < <(find "$dir" \( -name '*.ko' -o -name '*.ko.xz' -o -name '*.ko.zst' \) 2>/dev/null)
}

# Signs a vmlinuz in place with sbsign.
sign_vmlinuz() {
    local vmlinuz="$1" cert_pem
    cert_pem=$(mktemp /tmp/mok_cert.XXXXXX.pem)
    openssl x509 -in "$MOK_CERT_DER" -inform DER -out "$cert_pem" -outform PEM
    sbsign --key "$MOK_KEY" --cert "$cert_pem" --output "${vmlinuz}.signed" "$vmlinuz"
    mv "${vmlinuz}.signed" "$vmlinuz"
    rm -f "$cert_pem"
}
