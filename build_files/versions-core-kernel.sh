# Pinned versions consumed by common/core/080-xone-dkms.sh — split out so
# bumping this doesn't invalidate the cache of unrelated core RUN groups.
#
# Tracked by Renovate (.github/renovate.json5 customManagers). Bumped via
# PR — edit the value in a Renovate PR, don't move the annotation comment
# off its version line.

# xone (Xbox Wireless Adapter driver) — pinned to a commit, not a tag;
# upstream's tags stop at v0.3 and are stale.
# renovate: datasource=git-refs depName=https://github.com/medusalix/xone
XONE_COMMIT="3484f603484782dd7551c64e5a33fc602b127051"
