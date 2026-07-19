#!/usr/bin/env bash
# Generates Containerfile.generated (the file builds actually use) from the
# committed Containerfile skeleton plus COMPONENTS.list. Runs automatically
# before every build (`just build` dependency, CI build step); `just
# generate` runs it standalone. Containerfile.generated is gitignored: the
# committed Containerfile stays an honest skeleton with an empty component
# section, so nothing generated is ever committed.
#
# Each list entry becomes one RUN layer that calls lib/run-component.sh.
# Components under a [flavor] section get COMPONENT_FLAVORS=<flavor>
# injected (so run-component.sh skips them on other flavors). A component
# that needs extra mounts or env (build secrets, ARGs) ships a
# Containerfile.part in its directory, inlined verbatim instead of the
# standard block; if listed under a [flavor] section the generator
# cross-checks the part's COMPONENT_FLAVORS matches.
set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck disable=SC2016  # the backticks are literal marker text
begin='# ---- BEGIN COMPONENTS (generated at build time from COMPONENTS.list; see scripts/gen-containerfile.sh) ----'
end='# ---- END COMPONENTS ----'

list=COMPONENTS.list
flavors_file=FLAVORS.list
skeleton=Containerfile
out=Containerfile.generated

# ---- read valid flavor names from FLAVORS.list --------------------------
declare -A valid_flavors=()
while IFS= read -r fline; do
    entry="${fline%%#*}"
    entry="${entry//[[:space:]]/}"
    [ -z "$entry" ] && continue
    # strip optional hostname=<x> suffix
    name="${entry%%hostname=*}"
    valid_flavors["$name"]=1
done < "$flavors_file"

if [ "${#valid_flavors[@]}" -eq 0 ]; then
    echo "gen-containerfile: no flavors found in ${flavors_file}" >&2
    exit 1
fi

# ---- emit one component block -------------------------------------------
# <name> <variant> <flavor> — flavor is "" for universal
emit_block() {
    local name="$1" variant="$2" flavor="$3" dir rel d matches=()
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
        # Containerfile.part component: cross-check flavor gate if listed
        # under a [flavor] section, then emit verbatim.
        if [ -n "$flavor" ]; then
            local part_flavor
            part_flavor="$(sed -n 's/.*COMPONENT_FLAVORS=\([^[:space:]]*\).*/\1/p' "${dir}/Containerfile.part" | head -1)"
            if [ -z "$part_flavor" ]; then
                echo "gen-containerfile: '${name}' is listed under [${flavor}] but its Containerfile.part has no COMPONENT_FLAVORS — the flavor gate would be silently ignored" >&2
                exit 1
            fi
            if [ "$part_flavor" != "$flavor" ]; then
                echo "gen-containerfile: '${name}' is listed under [${flavor}] but its Containerfile.part has COMPONENT_FLAVORS=${part_flavor}" >&2
                exit 1
            fi
            printf '# ---- [%s] ----\n' "$flavor"
        fi
        printf '# ---- %s (verbatim from %s/Containerfile.part) ----\n' "$name" "$rel"
        cat "${dir}/Containerfile.part"
        return
    fi

    local env_prefix=""
    [ -n "$variant" ] && env_prefix="COMPONENT_VARIANT=${variant} "
    [ -n "$flavor" ] && env_prefix+="COMPONENT_FLAVORS=${flavor} "
    if [ -n "$flavor" ]; then
        printf '# ---- [%s] ----\n' "$flavor"
    fi
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

# ---- parse COMPONENTS.list ----------------------------------------------
section=""
current_flavor=""
while IFS= read -r line; do
    entry="${line%%#*}"
    entry="${entry//[[:space:]]/}"
    [ -z "$entry" ] && continue

    # INI section header: [flavor]
    if [[ "$entry" =~ ^\[([a-z][a-z0-9-]*)\]$ ]]; then
        current_flavor="${BASH_REMATCH[1]}"
        if [ -z "${valid_flavors[$current_flavor]:-}" ]; then
            echo "gen-containerfile: [${current_flavor}] is not a flavor in ${flavors_file}" >&2
            exit 1
        fi
        continue
    fi

    name="${entry%%@*}"
    variant=""
    [ "$entry" != "$name" ] && variant="${entry#*@}"

    section+="$(emit_block "$name" "$variant" "$current_flavor")"$'\n\n'
done < "$list"

# ---- splice into skeleton -----------------------------------------------
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
