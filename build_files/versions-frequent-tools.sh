# Pinned versions consumed by common/frequent/000-pinned-tools.sh — split
# into its own file so bumping one of these doesn't invalidate the cache of
# unrelated frequent RUN groups (network/browser, the flavor script).
#
# Tracked by Renovate (.github/renovate.json5 customManagers). Bumped via
# PR — edit the value in a Renovate PR, don't move the annotation comment
# off its version line.

# Bitwarden CLI. No official checksum is published, so BW_SHA256 pins the
# exact bytes fetched when this was added — it must be recomputed by hand
# whenever BW_VERSION bumps (a Renovate PR here needs a follow-up commit,
# it can't be auto-merged as-is).
# renovate: datasource=github-releases depName=bitwarden/clients extractVersion=^cli-v(?<version>.*)$
BW_VERSION="2026.6.0"
BW_SHA256="392549496c712ab86bfbd6c27302df9fd2c431cfc7a47e26941ac3e3893f4d27"

# aichat
# renovate: datasource=github-releases depName=sigoden/aichat
AICHAT_VERSION="0.30.0"

# Starship prompt
# renovate: datasource=github-releases depName=starship/starship
STARSHIP_VERSION="1.26.0"

# Nerd Fonts
# renovate: datasource=github-releases depName=ryanoasis/nerd-fonts
NERD_FONTS_VERSION="3.4.0"
