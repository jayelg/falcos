# Pinned versions consumed by common/core/020-kde-theming.sh — split into
# its own file (rather than one shared versions-core.sh) so bumping a
# theming pin doesn't invalidate the cache of unrelated core RUN groups
# (kernel/drivers, security, etc.) that don't reference these values.
#
# Tracked by Renovate (.github/renovate.json5 customManagers). Bumped via
# PR — edit the value in a Renovate PR, don't move the annotation comment
# off its version line.

# Darkly — Qt widget style + KWin window decoration
# renovate: datasource=github-tags depName=Bali10050/Darkly
DARKLY_VERSION="0.5.38"

# Ant-Dark plasma desktop theme — pinned to a commit; no tagged release
# contains the KDE theme (latest tag predates KDE support being added).
# renovate: datasource=git-refs depName=https://github.com/EliverLara/Ant
ANT_COMMIT="79ddc06b40ad1e96c87d9270c71d7db3bfa0c3cd"

# Advanced Weather Widget
# renovate: datasource=github-releases depName=pnedyalkov91/advanced-weather-widget
AWW_VERSION="1.6.3"
