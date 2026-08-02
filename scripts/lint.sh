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

# Every module the list pins, so the checks below see the same tree a
# build does rather than failing on a module that is not on disk yet.
./scripts/fetch-modules.sh

# -s bash because module scripts are sourced fragments without a
# shebang. Extensionless runtime scripts
# (libexec helpers, systemd generators) are matched by path instead of
# extension. Repo-wide excludes live in .shellcheckrc.
#
# modules/.remote is pruned: a fetched module is reviewed as a pin and
# cannot be edited here, so a style failure in one would block every
# build with nothing in this repository to fix.
mapfile -t scripts < <(
    find build-phases scripts lib modules -path modules/.remote -prune -o \
        -name '*.sh' -type f -print
    find modules -path modules/.remote -prune -o -path '*/files/*' -type f \
        \( -path '*/libexec/*' -o -path '*/system-generators/*' \) -print
)
shellcheck -s bash "${scripts[@]}"
echo "lint: shellcheck passed on ${#scripts[@]} scripts"

# Validates every manifest: unknown nodes and properties, flavor marks,
# entries that do not resolve to a module directory, and fragments whose
# gate disagrees with the list. Reports every problem at once, with the
# line each is on, rather than stopping at the first.
./scripts/manifest.sh check

# The allow-verify diagnostic classes are named in two places by
# necessity: lib/validate-image.sh holds the regex each one stands for,
# because a pattern must never cross into a build arg, and the parser
# holds the names, because a bad declaration should fail here in seconds
# rather than mid-build. Nothing else makes the two agree, so this does.
#
# Both extractions have to find something. A pattern that silently matched
# nothing would leave two empty lists comparing equal, which is the
# failure this exists to catch.
shell_classes="$(sed -n 's/^\t\[\([a-z-]*\)\]=.*/\1/p' lib/validate-image.sh | sort)"
parser_classes="$(sed -n 's/^const VERIFY_CLASSES[^=]*= \[\(.*\)\];$/\1/p' \
    tools/manifest/src/module.rs | tr -d '" ' | tr ',' '\n' | sort)"
if [ -z "$shell_classes" ]; then
    echo "lint: no verify classes found in lib/validate-image.sh" >&2
    exit 1
elif [ -z "$parser_classes" ]; then
    echo "lint: no VERIFY_CLASSES found in tools/manifest/src/module.rs" >&2
    exit 1
elif [ "$shell_classes" != "$parser_classes" ]; then
    echo "lint: the verify diagnostic classes disagree" >&2
    diff <(echo "$shell_classes") <(echo "$parser_classes") |
        sed 's/^</  only in validate-image.sh: /; s/^>/  only in module.rs:        /' >&2
    exit 1
fi
echo "lint: verify classes agree ($(echo "$shell_classes" | tr '\n' ' ' | sed 's/ *$//'))"

# Then the splice itself, which is the part manifest.sh does not own:
# skeleton marker damage would otherwise only surface at build time.
#
# Regenerating in place also checks the committed files, which are what a
# reviewer reads and what a build of this commit produces. Those have to
# be the same files, so a stale one is a diff here rather than a surprise
# in the next review.
./scripts/gen-containerfile.sh > /dev/null
mapfile -t generated < <(./scripts/manifest.sh images \
    | sed 's#^#containerfiles/#; s#$#.generated#')
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "lint: the Containerfiles generate (no checkout, so no drift check)"
else
    for file in "${generated[@]}"; do
        if ! git ls-files --error-unmatch "$file" > /dev/null 2>&1; then
            echo "lint: ${file} is untracked, so nothing reviews it" >&2
            exit 1
        elif ! git diff --quiet -- "$file"; then
            echo "lint: ${file} is stale, stage the regenerated file" >&2
            git --no-pager diff --stat -- "$file" >&2
            exit 1
        fi
    done

    # A tracked file no image produces any more is a leftover from a
    # renamed or deleted image. It is not stale, so the loop above cannot
    # see it, and it would sit there being reviewed as part of a build
    # that no longer happens.
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        for want in "${generated[@]}"; do
            [ "$file" != "$want" ] || continue 2
        done
        echo "lint: ${file} belongs to no declared image, remove it" >&2
        exit 1
    done < <(git ls-files 'containerfiles/*.generated')

    echo "lint: ${#generated[@]} Containerfile(s) generate and match the committed ones"
fi

# Renders the installer config the way a disk build does, so a template
# that stopped substituting, or a target that no longer resolves, fails
# here in seconds rather than during an installation on someone's
# machine. The namespace is a placeholder: what this checks is
# the template, not where the image lives.
IMAGE_REGISTRY=lint.invalid ./scripts/render-iso-config.sh > /dev/null
echo "lint: installer config renders"
