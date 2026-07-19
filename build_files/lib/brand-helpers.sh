#!/bin/bash
# os-release branding, sourced by 50-flavor.sh.
# Defaults NAME, PRETTY_NAME, IMAGE_VERSION and DEFAULT_HOSTNAME from the
# build environment; each default can be overridden by passing KEY=value
# arguments. In practice the defaults are always correct — the per-flavor
# override mechanism exists for future flavors that need different branding.

# NAME=<...> PRETTY_NAME=<...> DEFAULT_HOSTNAME=<...> — keys match the
# os-release fields they set. Patches branding fields only,
# VERSION/BUILD_ID/OSTREE_VERSION stay from the base image. Repo URLs are
# flavor-independent and set here.
# Targets /usr/lib/os-release: /etc/os-release is a symlink to it, and
# ostree reads the real file when writing GRUB entry titles. sed -i on the
# symlink would replace it with a patched copy and leave GRUB on the base
# image's name. The ln restores the symlink on images where it was already
# a detached file.
brand_os_release() {
    local name="Falcos" pretty_name="" default_hostname="${FLAVOR:-laptop}" image_version="${IMAGE_VERSION:-dev}" arg
    for arg in "$@"; do
        case "$arg" in
            NAME=*) name="${arg#NAME=}" ;;
            PRETTY_NAME=*) pretty_name="${arg#PRETTY_NAME=}" ;;
            DEFAULT_HOSTNAME=*) default_hostname="${arg#DEFAULT_HOSTNAME=}" ;;
            IMAGE_VERSION=*) image_version="${arg#IMAGE_VERSION=}" ;;
            *)
                echo "brand_os_release: unknown argument '${arg}'" >&2
                return 1
                ;;
        esac
    done
    if [ -z "$pretty_name" ]; then
        pretty_name="Falcos ${image_version}"
    fi

    sed -i \
        -e "s|^NAME=.*|NAME=\"${name}\"|" \
        -e "s|^PRETTY_NAME=.*|PRETTY_NAME=\"${pretty_name}\"|" \
        -e 's|^LOGO=.*|LOGO=distributor-logo-symbolic|' \
        -e "s|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME=\"${default_hostname}\"|" \
        -e 's|^HOME_URL=.*|HOME_URL="https://github.com/jayelg/falcos"|' \
        -e 's|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL="https://github.com/jayelg/falcos"|' \
        -e 's|^SUPPORT_URL=.*|SUPPORT_URL="https://github.com/jayelg/falcos/issues"|' \
        -e 's|^BUG_REPORT_URL=.*|BUG_REPORT_URL="https://github.com/jayelg/falcos/issues"|' \
        /usr/lib/os-release
    # The base image has no IMAGE_VERSION line, so a bare sed would no-op
    if grep -q '^IMAGE_VERSION=' /usr/lib/os-release; then
        sed -i "s|^IMAGE_VERSION=.*|IMAGE_VERSION=\"${image_version}\"|" /usr/lib/os-release
    else
        echo "IMAGE_VERSION=\"${image_version}\"" >> /usr/lib/os-release
    fi
    ln -sf ../usr/lib/os-release /etc/os-release
}
