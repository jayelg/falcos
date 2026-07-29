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

# -s bash because module scripts, versions files and variant overrides
# are sourced fragments without shebangs. Extensionless runtime scripts
# (libexec helpers, systemd generators) are matched by path instead of
# extension. Repo-wide excludes live in .shellcheckrc.
mapfile -t scripts < <(
    find build-phases scripts lib modules -name '*.sh' -type f
    find modules -path '*/files/*' -type f \
        \( -path '*/libexec/*' -o -path '*/system-generators/*' \)
)
shellcheck -s bash "${scripts[@]}"
echo "lint: shellcheck passed on ${#scripts[@]} scripts"

# Catches modules.list entries that don't resolve to a module
# directory, an undeclared flavor section and skeleton marker damage,
# without needing a full image build.
./scripts/gen-containerfile.sh > /dev/null
echo "lint: modules.list resolves"

# Renders the installer config the way a disk build does, so a template
# that stopped substituting, or an installer flavor that is no longer
# declared, fails here in seconds rather than during an installation on
# someone's machine. The namespace is a placeholder: what this checks is
# the template, not where the image lives.
IMAGE_REGISTRY=lint.invalid ./scripts/render-iso-config.sh > /dev/null
echo "lint: installer config renders"
