# Pinned version consumed by common/frequent/020-network-audio.sh — split
# out so bumping it doesn't invalidate unrelated frequent RUN groups.
#
# Tracked by Renovate (.github/renovate.json5 customManagers). Bumped via
# PR — edit the value in a Renovate PR, don't move the annotation comment
# off its version line.

# plasma-network-audio — own project, actively developed. The RPM asset
# filename doesn't derive cleanly from the tag (e.g. tag v0.1-alpha.1 ->
# asset "...-0.1-0.alpha_1.fc44.x86_64.rpm"), so a Renovate bump here still
# needs a manual follow-up to update the filename in
# common/frequent/020-network-audio.sh, same as BW_SHA256 in
# versions-frequent-tools.sh.
# renovate: datasource=github-releases depName=johngrantdev/plasma-network-audio
PLASMA_NETWORK_AUDIO_TAG="v0.1-alpha.1"
