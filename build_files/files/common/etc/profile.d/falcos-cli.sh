# Interactive alias for the OS TUI (falcos-cli): the OS name (lowercased)
# launches it, so `falcos` shows the system panel and recipe menu, and
# `falcos <recipe>` runs one. Read from /etc/os-release rather than
# hardcoded so a rebrand carries the alias with it. Subshell keeps NAME out
# of the environment.
case $- in
    *i*)
        __os_cli_name="$(. /etc/os-release 2>/dev/null && printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]')"
        # Alias name is intentionally the os-release NAME resolved now.
        # shellcheck disable=SC2139
        [ -n "$__os_cli_name" ] && alias "$__os_cli_name"='falcos-cli'
        unset __os_cli_name
        ;;
esac
