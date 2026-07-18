# shellcheck disable=SC2034  # versions here are consumed by the scripts sourced after this file
# Renovate-tracked pins for common/frequent/000-pinned-tools.sh. Keep each
# annotation comment directly above its version line.

# No official checksum is published (trust-on-first-use). When a PR bumps
# BW_VERSION, .github/workflows/checksums.yml recomputes BW_SHA256 from the
# release asset and pushes the fix to the PR branch.
# renovate: datasource=github-releases depName=bitwarden/clients extractVersion=^cli-v(?<version>.*)$
BW_VERSION="2026.6.0"
BW_SHA256="392549496c712ab86bfbd6c27302df9fd2c431cfc7a47e26941ac3e3893f4d27"

# renovate: datasource=github-releases depName=sigoden/aichat
AICHAT_VERSION="0.30.0"

# renovate: datasource=github-releases depName=starship/starship
STARSHIP_VERSION="1.26.0"

# renovate: datasource=github-releases depName=ryanoasis/nerd-fonts
NERD_FONTS_VERSION="3.4.0"

# HalFrgrd/flyline publishes a sha256 sidecar per release asset, so unlike
# BW_SHA256 above this pin starts accurate rather than trust-on-first-use;
# .github/workflows/checksums.yml keeps it in sync with FLYLINE_VERSION
# bumps the same way it does for the other pinned assets.
# renovate: datasource=github-releases depName=HalFrgrd/flyline
FLYLINE_VERSION="1.3.0"
FLYLINE_SHA256="21bb0a7a0e417496ff68ef8379cadc05d35e42aee357fc64ad9a8d95f69320f8"

# falcos-cli, the OS TUI aliased to the OS name. Own repo, prebuilt static
# binary; publishes a .sha256 sidecar per asset like flyline, so
# checksums.yml keeps FALCOS_CLI_SHA256 in sync with version bumps.
# renovate: datasource=github-releases depName=jayelg/falcos-cli
FALCOS_CLI_VERSION="0.1.1"
FALCOS_CLI_SHA256="396b530d915a8030bb02ef1917021e10199a43134b9aad8783b13e689dde50c4"
