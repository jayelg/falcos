# shellcheck disable=SC2034  # versions here are consumed by component.sh
# Renovate-tracked pin for falcos-tools.

# falcos-cli, the OS TUI aliased to the OS name. Own repo, prebuilt static
# binary; publishes a .sha256 sidecar per asset, so checksums.yml keeps
# FALCOS_CLI_SHA256 in sync with version bumps.
# renovate: datasource=github-releases depName=jayelg/falcos-cli
FALCOS_CLI_VERSION="0.1.3"
FALCOS_CLI_SHA256="476d78ddc866328090a78bf01651f05274a74fa8e7f498fe953170a06bb924c5"
