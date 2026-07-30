#!/usr/bin/env bash
# Repo lint. The single definition of what gets checked: CI (the shellcheck
# job in .github/workflows/build.yml) and `just lint` both call this, so the
# local check and the gate on the build cannot disagree about the file set.
#
# Not covered here: actionlint and the kernel-freshness unit tests, which run
# as their own CI jobs because they need tools this script would otherwise
# have to install.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v shellcheck > /dev/null 2>&1; then
    echo "lint: shellcheck not found, install it first" >&2
    exit 1
fi

# -s bash because module scripts are sourced fragments without a
# shebang. Extensionless runtime scripts
# (libexec helpers, systemd generators) are matched by path instead of
# extension. Repo-wide excludes live in .shellcheckrc.
mapfile -t scripts < <(
    find build-phases scripts lib modules -name '*.sh' -type f
    find modules -path '*/files/*' -type f \
        \( -path '*/libexec/*' -o -path '*/system-generators/*' \)
)
shellcheck -s bash "${scripts[@]}"
echo "lint: shellcheck passed on ${#scripts[@]} scripts"

# Validates every manifest: unknown nodes and properties, flavor marks,
# entries that do not resolve to a module directory, and fragments whose
# gate disagrees with the list. Reports every problem at once, with the
# line each is on, rather than stopping at the first.
./scripts/manifest.sh check

# Then the splice itself, which is the part manifest.sh does not own:
# skeleton marker damage would otherwise only surface at build time.
#
# Regenerating in place also checks the committed file, which is what a
# reviewer reads and what a build of this commit produces. Those have to
# be the same file, so a stale one is a diff here rather than a surprise
# in the next review.
./scripts/gen-containerfile.sh > /dev/null
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "lint: the Containerfile generates (no checkout, so no drift check)"
elif ! git ls-files --error-unmatch Containerfile.generated > /dev/null 2>&1; then
    echo "lint: Containerfile.generated is untracked, so nothing reviews it" >&2
    exit 1
elif ! git diff --quiet -- Containerfile.generated; then
    echo "lint: Containerfile.generated is stale, stage the regenerated file" >&2
    git --no-pager diff --stat -- Containerfile.generated >&2
    exit 1
else
    echo "lint: the Containerfile generates and matches the committed one"
fi

# Renders the installer config the way a disk build does, so a template
# that stopped substituting, or a target that no longer resolves, fails
# here in seconds rather than during an installation on someone's
# machine. The namespace is a placeholder: what this checks is
# the template, not where the image lives.
IMAGE_REGISTRY=lint.invalid ./scripts/render-iso-config.sh > /dev/null
echo "lint: installer config renders"
