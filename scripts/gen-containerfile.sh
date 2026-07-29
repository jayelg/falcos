#!/usr/bin/env bash
# Generates Containerfile.generated (the file builds actually use) from the
# committed Containerfile skeleton plus modules.list. scripts/build.sh
# runs it before every build, locally and in CI, so no build can use a
# stale one; `just generate` runs it standalone. Containerfile.generated
# is gitignored: the committed Containerfile stays an honest skeleton with
# an empty module section, so nothing generated is ever committed.
#
# Each list entry is a path relative to modules/. It becomes one RUN
# layer that calls lib/run-module.sh. Modules under a [flavor]
# section get FLAVOR_GATE=<flavor> injected (so run-module.sh
# skips them on other flavors). A module that needs extra mounts or env
# (build secrets, ARGs) ships a Containerfile.inc in its directory,
# inlined verbatim instead of the standard block; if listed under a
# [flavor] section the generator cross-checks the part's
# FLAVOR_GATE matches.
set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck disable=SC2016  # the backticks are literal marker text
begin='# ---- BEGIN MODULES (generated at build time from modules.list; see scripts/gen-containerfile.sh) ----'
end='# ---- END MODULES ----'

list=modules.list
skeleton=Containerfile.template
out=Containerfile.generated

# ---- read valid flavor names --------------------------------------------
# scripts/flavors.sh is the only thing that parses ARG FLAVORS; it validates
# the list and fails on a malformed one, so anything it prints is usable.
flavors_out="$(./scripts/flavors.sh list)"
first_flavor="$(./scripts/flavors.sh default)"
declare -A valid_flavors=()
while IFS= read -r name; do
    valid_flavors["$name"]=1
done <<< "$flavors_out"

# ---- ARG FLAVOR ----------------------------------------------------------
# Containerfile.template omits it because where it goes depends on the list.
# An ARG in scope is part of the cache key of every RUN below it, whether
# or not that RUN mentions it, so declaring it at the top of the section
# would fork the cache at the first module and leave two flavors
# sharing no layers at all. It is emitted directly above the first
# flavor-gated block instead, which is the first layer that can read it,
# and at the end of the section when nothing is gated, since the flavor
# and finalize phases below the section still need it.
#
# Everything above that point is flavor independent by construction: an
# ungated block's RUN never mentions FLAVOR, and run-module.sh only
# reads it when the generator set FLAVOR_GATE. A Containerfile.inc
# that breaks that is caught in emit_block.
flavor_arg_emitted=0
emit_flavor_arg() {
    cat <<EOF
# ---- flavor gate ----
# Declared here rather than above: an ARG in scope is part of the cache
# key of every RUN below it, so every layer above this one is shared by
# all flavors.
ARG FLAVOR=${first_flavor}
EOF
}

# ---- emit one module block -------------------------------------------
# <name> <variant> <flavor> — flavor is "" for universal
emit_block() {
    local name="$1" variant="$2" flavor="$3" dir
    dir="modules/${name}"
    if [ ! -d "$dir" ]; then
        echo "gen-containerfile: '${name}' does not resolve to a module directory (expected ${dir})" >&2
        exit 1
    fi

    if [ -f "${dir}/Containerfile.inc" ]; then
        # A part above the ARG that expands FLAVOR would get an empty
        # string, silently, so it is an error rather than a surprise in
        # the built image.
        if [ "$flavor_arg_emitted" = 0 ] \
            && grep -qE '\$\{?FLAVOR\}?' "${dir}/Containerfile.inc"; then
            echo "gen-containerfile: '${name}' expands FLAVOR in its Containerfile.inc but is listed above the first flavor-gated module, where ARG FLAVOR is not yet declared" >&2
            exit 1
        fi
        # Containerfile.inc module: cross-check flavor gate if listed
        # under a [flavor] section, then emit verbatim.
        if [ -n "$flavor" ]; then
            local part_flavor
            part_flavor="$(sed -n 's/.*FLAVOR_GATE=\([^[:space:]]*\).*/\1/p' "${dir}/Containerfile.inc" | head -1)"
            if [ -z "$part_flavor" ]; then
                echo "gen-containerfile: '${name}' is listed under [${flavor}] but its Containerfile.inc has no FLAVOR_GATE — the flavor gate would be silently ignored" >&2
                exit 1
            fi
            if [ "$part_flavor" != "$flavor" ]; then
                echo "gen-containerfile: '${name}' is listed under [${flavor}] but its Containerfile.inc has FLAVOR_GATE=${part_flavor}" >&2
                exit 1
            fi
            printf '# ---- [%s] ----\n' "$flavor"
        fi
        printf '# ---- %s (verbatim from %s/Containerfile.inc) ----\n' "$name" "$dir"
        cat "${dir}/Containerfile.inc"
        return
    fi

    local env_prefix=""
    [ -n "$variant" ] && env_prefix="MODULE_VARIANT=${variant} "
    [ -n "$flavor" ] && env_prefix+="FLAVOR_GATE=${flavor} "
    if [ -n "$flavor" ]; then
        printf '# ---- [%s] ----\n' "$flavor"
    fi
    cat <<EOF
# ---- ${name} ----
RUN --mount=type=bind,from=ctx,source=/${dir},target=/ctx/${dir} \\
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \\
    --mount=type=cache,target=/var/cache \\
    --mount=type=cache,target=/var/log \\
    --mount=type=tmpfs,target=/tmp \\
    ${env_prefix}bash /ctx/lib/run-module.sh /ctx/${dir}
EOF
}

# ---- parse modules.list -----------------------------------------------
current_flavor=""
finalize_order=()
while IFS= read -r line; do
    entry="${line%%#*}"
    entry="${entry//[[:space:]]/}"
    [ -z "$entry" ] && continue

    # INI section header: [flavor] or [common]
    if [[ "$entry" =~ ^\[([a-z][a-z0-9-]*)\]$ ]]; then
        section_name="${BASH_REMATCH[1]}"
        if [ "$section_name" = "common" ]; then
            current_flavor=""
        else
            current_flavor="$section_name"
            if [ -z "${valid_flavors[$current_flavor]:-}" ]; then
                echo "gen-containerfile: [${current_flavor}] is not a flavor in ARG FLAVORS in ${skeleton}" >&2
                exit 1
            fi
        fi
        continue
    fi

    name="${entry%%@*}"
    variant=""
    [ "$entry" != "$name" ] && variant="${entry#*@}"

    if [ -n "$current_flavor" ] && [ "$flavor_arg_emitted" = 0 ]; then
        section+="$(emit_flavor_arg)"$'\n\n'
        flavor_arg_emitted=1
    fi
    section+="$(emit_block "$name" "$variant" "$current_flavor")"$'\n\n'

    # Resolved here because this loop is already the one authority on
    # list order and flavor gating. The finalize phase used to reparse
    # the list inside the image to recover both, which was a second
    # implementation of this format that could drift from this one.
    if [ -f "modules/${name}/finalize.sh" ]; then
        finalize_order+=("${name}${current_flavor:+:${current_flavor}}")
    fi
done < "$list"

# Nothing gated, so nothing above needs it, but the phases below the
# section still do.
if [ "$flavor_arg_emitted" = 0 ]; then
    section+="$(emit_flavor_arg)"$'\n\n'
fi

# Consumed by the finalize phase below the section, which is why it is
# declared at the bottom of it. Each token is <path>, or <path>:<flavor>
# for a gated module, because which hooks run is still a per-flavor fact
# the build arg resolves and this file cannot.
section+="$(
    cat <<EOF
# ---- finalize hook order ----
# Modules shipping a finalize.sh, in list order, resolved on the host.
ARG FINALIZE_ORDER="${finalize_order[*]}"
EOF
)"$'\n\n'

# ---- splice into skeleton -----------------------------------------------
if ! grep -qxF "$begin" "$skeleton" || ! grep -qxF "$end" "$skeleton"; then
    echo "gen-containerfile: BEGIN/END MODULES markers not found in ${skeleton}" >&2
    exit 1
fi

# A parser directive is only a directive on the first line, so the
# skeleton's is hoisted above the generated-file header rather than being
# copied in place, where the header would push it down and BuildKit would
# read it as an ordinary comment.
directive=""
case "$(head -1 "$skeleton")" in
    '# syntax='*) directive="$(head -1 "$skeleton")" ;;
esac

section_file="$(mktemp)"
printf '%s' "$section" > "$section_file"
{
    [ -z "$directive" ] || echo "$directive"
    echo '# GENERATED FILE — do not edit. Produced by scripts/gen-containerfile.sh'
    echo '# from the Containerfile skeleton and modules.list.'
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
rm -f "$section_file"
echo "gen-containerfile: wrote ${out} ($(grep -c 'run-module.sh /ctx' "$out") module RUN layers)"
