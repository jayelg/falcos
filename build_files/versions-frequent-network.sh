# shellcheck disable=SC2034  # versions here are consumed by the scripts sourced after this file
# Renovate-tracked pins for common/frequent/020-custom-apps.sh. Keep each
# annotation comment directly above its version line.
#
# Both RPMs carry a SHA256 because dnf5 doesn't GPG-check URL-installed
# RPMs and release tags are mutable (trust-on-first-use, like the pins in
# versions-frequent-affinity.sh).

# The RPM asset filename doesn't derive cleanly from the tag, so a Renovate
# bump here needs a manual follow-up to update the filename in
# common/frequent/020-custom-apps.sh and recompute the SHA256 below —
# checksums.yml can't cover it for the same reason.
# renovate: datasource=github-releases depName=johngrantdev/plasma-network-audio
PLASMA_NETWORK_AUDIO_TAG="v0.1-alpha.1"
PLASMA_NETWORK_AUDIO_SHA256="685cffb92549d8eb8c31e598782ae29c99f859bfd8adef842ee9ee8821864b4e"

# No manual follow-up here: the asset filename derives from the version,
# which relies on releases keeping tag = v<rpm version> and release -1.
# .github/workflows/checksums.yml recomputes the SHA256 on bumps.
# renovate: datasource=github-releases depName=jayelg/falcos-bootc-updates extractVersion=^v(?<version>.*)$
FALCOS_BOOTC_UPDATES_VERSION="0.1.1"
FALCOS_BOOTC_UPDATES_SHA256="2272f4682aff39bd0bff7b2b13db71854da971eda99b6e84653ba1da32d94b7a"
