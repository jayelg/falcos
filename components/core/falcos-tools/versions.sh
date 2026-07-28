# shellcheck disable=SC2034  # versions here are consumed by component.sh
# Renovate-tracked pin for falcos-tools.

# goojust, the OS TUI aliased to the OS name. Own repo, prebuilt static
# binary; publishes a .sha256 sidecar per asset, so checksums.yml keeps
# GOOJUST_SHA256 in sync with version bumps.
# renovate: datasource=github-releases depName=jayelg/goojust
GOOJUST_VERSION="0.1.5"
GOOJUST_SHA256="b5555c822de33e74793d43d99df27adaebc9f4be08dc956e8d7cbfb2a5121375"
