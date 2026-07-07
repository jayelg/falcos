### Branding
# Patch os-release branding fields only, VERSION/BUILD_ID/OSTREE_VERSION
# stay from the base image
sed -i \
    -e 's|^NAME=.*|NAME="Framework OS"|' \
    -e 's|^PRETTY_NAME=.*|PRETTY_NAME="Framework OS (falcos:laptop)"|' \
    -e 's|^LOGO=.*|LOGO=distributor-logo-symbolic|' \
    -e 's|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME="framework"|' \
    -e 's|^HOME_URL=.*|HOME_URL="https://github.com/jayelg/falcos"|' \
    -e 's|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL="https://github.com/jayelg/falcos"|' \
    -e 's|^SUPPORT_URL=.*|SUPPORT_URL="https://github.com/jayelg/falcos/issues"|' \
    -e 's|^BUG_REPORT_URL=.*|BUG_REPORT_URL="https://github.com/jayelg/falcos/issues"|' \
    /etc/os-release
