#!/bin/bash
# os-release branding and the brand assets, sourced by 50-flavor.sh.
#
# Every value comes from the image's own declaration, which the generator
# emits as the IMAGE_* ARGs this phase is passed. Nothing here has a
# default for the brand: an unset name is a manifest that failed to
# declare one, not something to guess at. The one default is PRETTY_NAME,
# which is a format over the others rather than a value of its own.

# Patches branding fields only, VERSION/BUILD_ID/OSTREE_VERSION stay from
# the base image. Targets /usr/lib/os-release: /etc/os-release is a
# symlink to it, and ostree reads the real file when writing GRUB entry
# titles. sed -i on the symlink would replace it with a patched copy and
# leave GRUB on the base image's name. The ln restores the symlink on
# images where it was already a detached file.
brand_os_release() {
    local name="${IMAGE_NAME:?IMAGE_NAME is unset: the image declares no name}"
    local image_version="${IMAGE_VERSION:-dev}"
    local pretty_name="${IMAGE_PRETTY_NAME:-${name} ${image_version}}"
    # The brand, not the flavor. A flavor is an image variant, not a
    # machine identity, and the ungated build has no flavor to follow.
    local default_hostname="${IMAGE_ID:-${name,,}}"

    sed -i \
        -e "s|^NAME=.*|NAME=\"${name}\"|" \
        -e "s|^PRETTY_NAME=.*|PRETTY_NAME=\"${pretty_name}\"|" \
        -e "s|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME=\"${default_hostname}\"|" \
        /usr/lib/os-release

    # Only what was declared: an undeclared URL leaves the base image's
    # own, which is a working link, where an empty one is a dead field.
    if [ -n "${IMAGE_URL:-}" ]; then
        sed -i \
            -e "s|^HOME_URL=.*|HOME_URL=\"${IMAGE_URL}\"|" \
            -e "s|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL=\"${IMAGE_URL}\"|" \
            /usr/lib/os-release
    fi
    if [ -n "${IMAGE_ISSUES_URL:-}" ]; then
        sed -i \
            -e "s|^SUPPORT_URL=.*|SUPPORT_URL=\"${IMAGE_ISSUES_URL}\"|" \
            -e "s|^BUG_REPORT_URL=.*|BUG_REPORT_URL=\"${IMAGE_ISSUES_URL}\"|" \
            /usr/lib/os-release
    fi

    # The base image has no IMAGE_VERSION line, so a bare sed would no-op
    if grep -q '^IMAGE_VERSION=' /usr/lib/os-release; then
        sed -i "s|^IMAGE_VERSION=.*|IMAGE_VERSION=\"${image_version}\"|" /usr/lib/os-release
    else
        echo "IMAGE_VERSION=\"${image_version}\"" >> /usr/lib/os-release
    fi
    ln -sf ../usr/lib/os-release /etc/os-release
}

# The declared brand assets, bind mounted under /ctx with the rest of the
# build context. Both are optional: an image that declares neither keeps
# the base image's icon and boot splash.
#
# LOGO is the icon name, so it is derived from the file's own name rather
# than declared beside it, which is what stops os-release from naming an
# icon the image does not carry.
install_brand_assets() {
    local logo="${IMAGE_LOGO:-}" watermark="${IMAGE_WATERMARK:-}" file

    if [ -n "$logo" ]; then
        file="$(basename "$logo")"
        install -Dm644 "/ctx/${logo}" \
            "/usr/share/icons/hicolor/scalable/places/${file}"
        sed -i "s|^LOGO=.*|LOGO=${file%.*}|" /usr/lib/os-release
    fi

    if [ -n "$watermark" ]; then
        install -Dm644 "/ctx/${watermark}" \
            "/usr/share/plymouth/themes/spinner/watermark.png"
    fi
}
