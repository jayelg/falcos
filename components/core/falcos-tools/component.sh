# falcos-tools

# Fastfetch - required for goojust below
dnf5 install -y just fastfetch

source /ctx/lib/fetch-helpers.sh

### goojust — an OS TUI for running justfiles on the system
# dependancies:
#   - just
#   - fastfetch
fetch_extract "https://github.com/jayelg/goojust/releases/download/v${GOOJUST_VERSION}/goojust-v${GOOJUST_VERSION}-x86_64-linux-gnu.tar.gz" \
    "$GOOJUST_SHA256" /tmp
# --no-config: we ship our own config.toml in files/. run-component.sh copies
# files/ after this script, so the overlay would win either way, but skipping
# the seed keeps the image's justfile path ours alone rather than silently
# inheriting whatever the installer defaults to.
bash /tmp/install.sh --no-config
rm -rf /tmp/goojust /tmp/install.sh /tmp/scripts/
