#!/usr/bin/env bash
# Splices the generated module section into the Containerfile skeleton and
# writes Containerfile.generated, which is the file builds actually use.
# scripts/build.sh runs this before every build, locally and in CI, so no
# build can use a stale one; `just generate` runs it standalone.
#
# The section itself comes from scripts/manifest.sh, the only thing that
# reads modules.kdl. What stays here is the part that is about this file
# rather than about the manifest: finding the markers, and keeping the
# parser directive on line one.
set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck disable=SC2016  # the marker is literal text, not an expansion
begin='# ---- BEGIN MODULES (generated at build time from modules.kdl; see scripts/gen-containerfile.sh) ----'
end='# ---- END MODULES ----'

skeleton=Containerfile.template
out=Containerfile.generated

if ! grep -qxF "$begin" "$skeleton" || ! grep -qxF "$end" "$skeleton"; then
    echo "gen-containerfile: BEGIN/END MODULES markers not found in ${skeleton}" >&2
    exit 1
fi

# Written to a file rather than held in a variable: the section ends in a
# blank line, which a command substitution would strip.
section_file="$(mktemp)"
trap 'rm -f "$section_file"' EXIT
./scripts/manifest.sh section > "$section_file"

# A parser directive is only a directive on the first line, so the
# skeleton's is hoisted above the generated-file header rather than being
# copied in place, where the header would push it down and BuildKit would
# read it as an ordinary comment.
directive=""
case "$(head -1 "$skeleton")" in
    '# syntax='*) directive="$(head -1 "$skeleton")" ;;
esac

{
    [ -z "$directive" ] || echo "$directive"
    echo '# GENERATED FILE — do not edit. Produced by scripts/gen-containerfile.sh'
    echo '# from the Containerfile skeleton and modules.kdl.'
    echo
    awk -v begin="$begin" -v end="$end" -v sec="$section_file" -v directive="$directive" '
        NR == 1 && directive != "" && $0 == directive { next }
        $0 == begin {
            print
            print ""
            while ((getline sline < sec) > 0) print sline
            insection = 1
            next
        }
        $0 == end { insection = 0 }
        !insection { print }
    ' "$skeleton"
} > "$out"

echo "gen-containerfile: wrote ${out} ($(grep -c 'run-module.sh /ctx' "$out") module RUN layers)"
