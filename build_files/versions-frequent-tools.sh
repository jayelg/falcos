# shellcheck disable=SC2034  # versions here are consumed by the scripts sourced after this file
# Renovate-tracked pins for common/frequent/000-pinned-tools.sh. Keep each
# annotation comment directly above its version line.

# No official checksum is published (trust-on-first-use). When a PR bumps
# BW_VERSION, .github/workflows/checksums.yml recomputes BW_SHA256 from the
# release asset and pushes the fix to the PR branch.
# renovate: datasource=github-releases depName=bitwarden/clients extractVersion=^cli-v(?<version>.*)$
BW_VERSION="2026.6.0"
BW_SHA256="392549496c712ab86bfbd6c27302df9fd2c431cfc7a47e26941ac3e3893f4d27"

# No official checksum published, trust-on-first-use like BW_SHA256
# renovate: datasource=github-releases depName=sigoden/aichat
AICHAT_VERSION="0.30.0"
AICHAT_SHA256="6b0cc08c5ceb551dc52bfac2221752f82215be5908c70605d655e9b91ab1557c"

# Publishes a sha256 sidecar per asset, accurate from the start like flyline
# renovate: datasource=github-releases depName=starship/starship
STARSHIP_VERSION="1.26.0"
STARSHIP_SHA256="b7c232b0e8249d8e55a40beb79c5c43a7d370f3f9408bd215deb0170daeaadf3"

# The SHA is of the release's SHA-256.txt manifest, not a font archive; the
# build verifies the manifest against this pin, then each font against the
# manifest, so one pin covers every font in NERD_FONTS
# renovate: datasource=github-releases depName=ryanoasis/nerd-fonts
NERD_FONTS_VERSION="3.4.0"
NERD_FONTS_SHA256="1f38c8463bd370edddcae7a4b346b42607c8168227eb0ff5b6b4c54bdf744389"

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
FALCOS_CLI_VERSION="0.1.2"
FALCOS_CLI_SHA256="975eb7a7d7fee1e528c35b782bb057bd813c1ab6173c4546778af9448bc3c270"
