# shellcheck disable=SC2034  # versions here are consumed by the scripts sourced after this file
# Renovate-tracked pins for common/frequent/000-pinned-tools.sh. Keep each
# annotation comment directly above its version line.

# No official checksum is published. When a PR bumps BW_VERSION,
# .github/workflows/bw-checksum.yml recomputes BW_SHA256 from the release
# asset and pushes the fix to the PR branch.
# renovate: datasource=github-releases depName=bitwarden/clients extractVersion=^cli-v(?<version>.*)$
BW_VERSION="2026.6.0"
BW_SHA256="392549496c712ab86bfbd6c27302df9fd2c431cfc7a47e26941ac3e3893f4d27"

# renovate: datasource=github-releases depName=sigoden/aichat
AICHAT_VERSION="0.30.0"

# renovate: datasource=github-releases depName=starship/starship
STARSHIP_VERSION="1.26.0"

# renovate: datasource=github-releases depName=ryanoasis/nerd-fonts
NERD_FONTS_VERSION="3.4.0"
