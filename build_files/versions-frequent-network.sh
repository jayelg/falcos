# shellcheck disable=SC2034  # versions here are consumed by the scripts sourced after this file
# Renovate-tracked pins for common/frequent/020-custom-apps.sh. Keep each
# annotation comment directly above its version line.

# The RPM asset filename doesn't derive cleanly from the tag, so a Renovate
# bump here needs a manual follow-up to update the filename in
# common/frequent/020-custom-apps.sh.
# renovate: datasource=github-releases depName=johngrantdev/plasma-network-audio
PLASMA_NETWORK_AUDIO_TAG="v0.1-alpha.1"

# No manual follow-up here: the asset filename is derived from the tag,
# which relies on releases keeping tag = v<rpm version> and release -1.
# renovate: datasource=github-releases depName=jayelg/falcos-bootc-updates
FALCOS_BOOTC_UPDATES_TAG="v0.1.1"
