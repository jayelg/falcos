# shellcheck disable=SC2034  # versions here are consumed by component.sh
# Renovate-tracked pin for falcos-tools.

# goojust, the OS TUI aliased to the OS name. Own repo, prebuilt static
# binary; publishes a .sha256 sidecar per asset, so checksums.yml keeps
# GOOJUST_SHA256 in sync with version bumps.
# renovate: datasource=github-releases depName=jayelg/goojust
GOOJUST_VERSION="0.1.4"
GOOJUST_SHA256="809dafd10d429f0f1d316cb3978b4a212f3ed588b6f1bdd1d233f5ae4def8ef3"
