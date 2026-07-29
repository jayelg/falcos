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

# -s bash because component scripts, versions files and variant overrides
# are sourced fragments without shebangs. Extensionless runtime scripts
# (libexec helpers, systemd generators) are matched by path instead of
# extension. Repo-wide excludes live in .shellcheckrc.
mapfile -t scripts < <(
    find build-phases scripts lib components -name '*.sh' -type f
    find components -path '*/files/*' -type f \
        \( -path '*/libexec/*' -o -path '*/system-generators/*' \)
)
shellcheck -s bash "${scripts[@]}"
echo "lint: shellcheck passed on ${#scripts[@]} scripts"

# Catches components.list entries that don't resolve to a component
# directory, an undeclared flavor section and skeleton marker damage,
# without needing a full image build.
./scripts/gen-containerfile.sh > /dev/null
echo "lint: components.list resolves"
