if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

    # brew shellenv prepends its own bin/sbin ahead of everything already in
    # PATH, which silently shadows same-named system tools (e.g. podman —
    # Homebrew's build fails with permission errors under rootless podman's
    # actual storage setup here) with Homebrew's own build. Move Homebrew's
    # dirs to the end instead: still available for anything the system
    # doesn't already provide, but never wins a name collision.
    HOMEBREW_PATHS="${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin"
    PATH="$(echo "$PATH" | tr ':' '\n' | grep -vF "${HOMEBREW_PREFIX}/" | tr '\n' ':')"
    PATH="${PATH%:}:${HOMEBREW_PATHS}"
    export PATH
    unset HOMEBREW_PATHS
fi
