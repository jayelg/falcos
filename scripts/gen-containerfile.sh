#!/usr/bin/env bash
# Splices the generated section — the build phase layers and the module
# layers — into the Containerfile skeleton and writes one Containerfile
# per declared image, into containerfiles/, which is what builds actually
# use. scripts/build.sh runs this before every build, locally and in CI,
# so no build can use a stale one; `just generate` runs it standalone.
#
# One file per image rather than one file with a switch in it: images
# build on different bases, so the FROM alone makes them separate
# Containerfiles, and a build has to be handed the one for the image it is
# building. They are named for the image, not for the file it was declared
# in, because a build target names an image and nothing downstream knows
# which file it came from.
#
# Not under build/, which is gitignored, even though these are generated:
# the expanded build is what a change to a module is reviewed as, so the
# files are tracked and lint fails when they are stale.
#
# The section itself comes from scripts/manifest.sh, the only thing that
# reads image.kdl and build-phases/. What stays here is the part that is
# about this file rather than about the manifest: finding the markers, and
# keeping the parser directive on line one.
#
# The skeleton lives beside this script rather than at the repository
# root. It holds no decisions about the image and is not a file anyone
# edits to change one — the base image, the modules and the build phases
# are all declared elsewhere and spliced in — so at the root it was a
# second Containerfile that looked editable and was not. What is left in
# it is the frame around the build: the parser directive, the context
# stage and the pre-publish lint gate. The root keeps no Containerfile at
# all: the generated ones are in containerfiles/, one per image, and those
# are what actually build.
#
# The lint gate stayed in the skeleton rather than becoming a build phase.
# A phase layer is handed cache mounts over /var/cache and /var/log, a
# tmpfs over /tmp and the whole module tree, and `bootc container lint`
# should see the image as it will ship rather than with four mounts over
# it. It is also a gate: unconditional and last, which a listed, numbered,
# reorderable phase would stop being.
set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck disable=SC2016  # the marker is literal text, not an expansion
begin='# ---- BEGIN GENERATED (build phases and modules; see scripts/gen-containerfile.sh) ----'
end='# ---- END GENERATED ----'

skeleton=scripts/Containerfile.skeleton
outdir=containerfiles

if ! grep -qxF "$begin" "$skeleton" || ! grep -qxF "$end" "$skeleton"; then
    echo "gen-containerfile: BEGIN/END GENERATED markers not found in ${skeleton}" >&2
    exit 1
fi

# Out-of-tree modules first: the section below emits a layer per module
# directory, so anything image.kdl pins has to be on disk before the
# generator reads it. A no-op when nothing is pinned, and offline when
# everything is already fetched.
./scripts/fetch-modules.sh

# A parser directive is only a directive on the first line, so the
# skeleton's is hoisted above the generated-file header rather than being
# copied in place, where the header would push it down and BuildKit would
# read it as an ordinary comment.
directive=""
case "$(head -1 "$skeleton")" in
    '# syntax='*) directive="$(head -1 "$skeleton")" ;;
esac

# Written to a file rather than held in a variable: a section ends in a
# blank line, which a command substitution would strip.
section_file="$(mktemp)"
trap 'rm -f "$section_file"' EXIT

mkdir -p "$outdir"

mapfile -t images < <(./scripts/manifest.sh images)
if [ "${#images[@]}" -eq 0 ]; then
    echo "gen-containerfile: no images declared, so there is nothing to generate" >&2
    exit 1
fi

for image in "${images[@]}"; do
    out="${outdir}/${image}.generated"
    ./scripts/manifest.sh section "$image" > "$section_file"

    {
        [ -z "$directive" ] || echo "$directive"
        echo '# GENERATED FILE — do not edit. Produced by scripts/gen-containerfile.sh'
        echo "# from the Containerfile skeleton and the ${image} image definition."
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

    echo "gen-containerfile: wrote ${out} ($(grep -c 'run-module.sh /ctx' "$out") module layers,\
 $(grep -c '^# ---- phase ' "$out") build phases)"
done
