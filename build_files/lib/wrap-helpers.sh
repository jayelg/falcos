#!/bin/bash
# hardened_malloc is preloaded system-wide via
# files/common/etc/environment.d/30-hardened-malloc.conf (see
# common/core/130-hardening.sh). Apps that crash under it get wrapped at
# install time with this helper; runtime exemptions are handled by
# `ujust hardened-malloc-exempt`. Standalone so RUN layers can mount just
# this file without pulling in the rest of lib/.

# <binary> — renames <binary> to <binary>.bin and installs a wrapper that
# execs it with LD_PRELOAD stripped.
wrap_no_hardened_malloc() {
    local bin="$1"
    if [ ! -f "$bin" ]; then
        echo "wrap_no_hardened_malloc: $bin not found" >&2
        return 1
    fi
    [ -f "${bin}.bin" ] && return 0
    mv "$bin" "${bin}.bin"
    cat > "$bin" <<EOF
#!/bin/bash
exec env -u LD_PRELOAD "${bin}.bin" "\$@"
EOF
    chmod 755 "$bin"
}
