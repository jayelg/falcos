#!/bin/bash
# os-release branding, sourced by the flavor scripts (desktop.sh/laptop.sh).

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
    local name="" pretty_name="" default_hostname="" arg
    for arg in "$@"; do
        case "$arg" in
            NAME=*) name="${arg#NAME=}" ;;
            PRETTY_NAME=*) pretty_name="${arg#PRETTY_NAME=}" ;;
            DEFAULT_HOSTNAME=*) default_hostname="${arg#DEFAULT_HOSTNAME=}" ;;
            *)
                echo "brand_os_release: unknown argument '${arg}'" >&2
                return 1
                ;;
        esac
    done
    if [ -z "$name" ] || [ -z "$pretty_name" ] || [ -z "$default_hostname" ]; then
        echo "brand_os_release: NAME=, PRETTY_NAME= and DEFAULT_HOSTNAME= are all required" >&2
        return 1
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
    ln -sf ../usr/lib/os-release /etc/os-release
}
