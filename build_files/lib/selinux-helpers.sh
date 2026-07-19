#!/bin/bash
# SELinux policy module install helper, sourced by scripts that ship a
# local .te policy (common/core/140-selinux.sh, components/trivalent/component.sh).
# Standalone so RUN layers can mount just this file.

# <te-file> — compiles the .te source and installs it into the targeted
# store at priority 200. -n skips the policy reload, which can't happen in
# a container build. Cleans up the .te and intermediate files.
install_selinux_module() {
    local te="$1"
    local base="${te%.te}"
    checkmodule -M -m -o "${base}.mod" "$te"
    semodule_package -o "${base}.pp" -m "${base}.mod"
    semodule -n -s targeted -X 200 -i "${base}.pp"
    rm -f "$te" "${base}.mod" "${base}.pp"
}
