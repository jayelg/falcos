#!/usr/bin/env bash
# The way everything reaches the manifest parser. Callers run
# `./scripts/manifest.sh <command>` and never think about where the
# binary is or whether it is current.
#
# The parser is Rust because it grows: past reading the list it has to
# resolve a capability graph, type-check options and verify pinned
# archives, and the errors it prints are the whole point of validating on
# the host. It is build tooling, never shipped in the image, so the cost
# is a toolchain on machines that build falcos rather than anything a
# user of the image carries.
#
# Rebuilt when a source file is newer than the binary. cargo is
# incremental and a no-op check costs about a tenth of a second, but
# checking here keeps that off every call in a loop.
set -euo pipefail
cd "$(dirname "$0")/.."

crate=tools/manifest
bin="${crate}/target/release/manifest"

die() {
    echo "manifest: $*" >&2
    exit 1
}

stale() {
    [ -x "$bin" ] || return 0
    [ -n "$(find "${crate}/src" "${crate}/Cargo.toml" "${crate}/Cargo.lock" \
        -newer "$bin" -print -quit 2> /dev/null)" ]
}

if stale; then
    command -v cargo > /dev/null 2>&1 || die "$(
        cat <<'EOF'
cargo not found, and the manifest parser has to be built before anything
can read the image files.

  rustup:  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  brew:    brew install rust
  fedora:  sudo dnf install cargo   (not on an image-based system)

CI needs no setup: the runner image ships a Rust toolchain.
EOF
    )"
    # --locked so a build never silently resolves a different dependency
    # tree than the one committed in Cargo.lock.
    cargo build --release --locked --quiet --manifest-path "${crate}/Cargo.toml" >&2
fi

exec "$bin" "$@"
