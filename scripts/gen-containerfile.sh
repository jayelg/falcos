#!/usr/bin/env bash
# Generates Containerfile.generated (the file builds actually use) from the
# committed Containerfile skeleton plus COMPONENTS.list. Runs automatically
# before every build (`just build` dependency, CI build step); `just
# generate` runs it standalone. Containerfile.generated is gitignored: the
# committed Containerfile stays an honest skeleton with an empty component
# section, so nothing generated is ever committed.
#
# Each list entry becomes one RUN layer that calls lib/run-component.sh.
# A component that needs extra mounts or env (build secrets, ARGs) ships
# a Containerfile.part in its directory, inlined verbatim instead of the
# standard block.
set -euo pipefail
cd "$(dirname "$0")/.."

list=COMPONENTS.list
skeleton=Containerfile
out=Containerfile.generated
# shellcheck disable=SC2016  # the backticks are literal marker text
begin='# ---- BEGIN COMPONENTS (generated at build time from COMPONENTS.list; see scripts/gen-containerfile.sh) ----'
end='# ---- END COMPONENTS ----'

# <name> <variant> — prints the Containerfile block for one component
emit_block() {
    local name="$1" variant="$2" dir rel d matches=()
    for d in "build_files/components/${name}" build_files/components/*/"${name}"; do
        [ -d "$d" ] && matches+=("$d")
    done
    if [ "${#matches[@]}" -ne 1 ]; then
        echo "gen-containerfile: '${name}' matches ${#matches[@]} directories under build_files/components/" >&2
        exit 1
    fi
    dir="${matches[0]}"
    rel="${dir#build_files/}"

    if [ -f "${dir}/Containerfile.part" ]; then
        printf '# ---- %s (verbatim from %s/Containerfile.part) ----\n' "$name" "$rel"
        cat "${dir}/Containerfile.part"
        return
    fi

    local env_prefix=""
    [ -n "$variant" ] && env_prefix="COMPONENT_VARIANT=${variant} "
    cat <<EOF
# ---- ${name} ----
RUN --mount=type=bind,from=ctx,source=/${rel},target=/ctx/${rel} \\
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \\
    --mount=type=cache,target=/var/cache \\
    --mount=type=cache,target=/var/log \\
    --mount=type=tmpfs,target=/tmp \\
    ${env_prefix}bash /ctx/lib/run-component.sh /ctx/${rel}
EOF
}

section=""
while IFS= read -r line; do
    entry="${line%%#*}"
    entry="${entry//[[:space:]]/}"
    [ -z "$entry" ] && continue
    name="${entry%%@*}"
    variant=""
    [ "$entry" != "$name" ] && variant="${entry#*@}"
    section+="$(emit_block "$name" "$variant")"$'\n\n'
done < "$list"

if ! grep -qxF "$begin" "$skeleton" || ! grep -qxF "$end" "$skeleton"; then
    echo "gen-containerfile: BEGIN/END COMPONENTS markers not found in ${skeleton}" >&2
    exit 1
fi

section_file="$(mktemp)"
printf '%s' "$section" > "$section_file"
{
    echo '# GENERATED FILE — do not edit. Produced by scripts/gen-containerfile.sh'
    echo '# from the Containerfile skeleton and COMPONENTS.list.'
    echo
    awk -v begin="$begin" -v end="$end" -v sec="$section_file" '
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
rm -f "$section_file"
echo "gen-containerfile: wrote ${out} ($(grep -c 'run-component.sh /ctx' "$out") component RUN layers)"
