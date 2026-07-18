# shellcheck disable=SC2034  # versions here are consumed by the scripts sourced after this file
# Renovate-tracked pins for common/core/020-kde-theming.sh. Keep each
# annotation comment directly above its version line.

# The SHA256 pins here are trust-on-first-use (no upstream checksums);
# .github/workflows/checksums.yml recomputes them when a PR bumps a version.
# Darkly and Ant hash GitHub source tarballs, which GitHub does not formally
# guarantee byte-stable; if one ever changes wholesale, the next version bump
# self-heals via the workflow.

# renovate: datasource=github-tags depName=Bali10050/Darkly
DARKLY_VERSION="0.5.38"
DARKLY_SHA256="6ffb293b9b109fe4a4f8aad20027edb640f063fbc5e7b3621ec58762e42f4bbb"

# Pinned to a commit, no tagged release contains the KDE theme
# renovate: datasource=git-refs depName=https://github.com/EliverLara/Ant
ANT_COMMIT="79ddc06b40ad1e96c87d9270c71d7db3bfa0c3cd"
ANT_SHA256="1eea917d8afc1151ee6c6287d216490bce9d7a5e555450d5b6e626970fa478d4"

# renovate: datasource=github-releases depName=pnedyalkov91/advanced-weather-widget
AWW_VERSION="1.6.3"
AWW_SHA256="4bfc4f3163014a4d23b225739e8ccfaa8bdea4736779c193c16f97f17f13351e"
