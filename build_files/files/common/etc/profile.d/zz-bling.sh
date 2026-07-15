[ "${BLING_SOURCED:-0}" -eq 1 ] && return
BLING_SOURCED=1

# ls aliases
if command -v eza >/dev/null; then
    alias ll='eza -l --icons=auto --group-directories-first'
    alias l.='eza -d .*'
    alias ls='eza'
    alias l1='eza -1'
fi

# ugrep for grep
if command -v ug >/dev/null; then
    alias grep='ug'
    alias egrep='ug -E'
    alias fgrep='ug -F'
    alias xzgrep='ug -z'
    alias xzegrep='ug -zE'
    alias xzfgrep='ug -zF'
fi

# bat for cat
if command -v bat >/dev/null; then
    alias cat='bat --style=plain --pager=never'
fi

BLING_SHELL="$(basename "$(readlink /proc/$$/exe)")"

command -v direnv >/dev/null && eval "$(direnv hook "${BLING_SHELL}")"
command -v zoxide >/dev/null && eval "$(zoxide init "${BLING_SHELL}")"

# Flyline replaces readline itself (prompts, tab completion, history search),
# so it's Bash-only unlike the shell-agnostic hooks above.
if [ "${BLING_SHELL}" = "bash" ] && [ -r /usr/lib/bash/libflyline.so ]; then
    enable -f /usr/lib/bash/libflyline.so flyline
fi
