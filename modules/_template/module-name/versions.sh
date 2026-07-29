# versions.sh — Renovate-tracked version pins + checksums. OPTIONAL: only
# needed when module.sh downloads a pinned release asset. Sourced before
# module.sh so these vars are in scope there.
#
# The `# renovate:` comment is position-sensitive (must sit directly above
# its version line) — it tells Renovate what upstream to watch. If the asset
# has no upstream-published checksum, .github/workflows/checksums.yml can
# recompute the SHA on version bumps; add the module's versions.sh path to
# that workflow's `paths:` trigger and `entries` list.

# shellcheck disable=SC2034  # consumed by module.sh, not this file
# renovate: datasource=github-releases depName=example-org/example-tool
TEMPLATE_VERSION="1.0.0"
TEMPLATE_SHA256="0000000000000000000000000000000000000000000000000000000000000000"
