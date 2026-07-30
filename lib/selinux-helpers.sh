#!/bin/bash
# SELinux policy module install helper, sourced by lib/run-module.sh for
# any module shipping a selinux/ directory and by the finalize phase for
# the composefs workaround. Standalone so RUN layers can mount just this
# file.

# checkmodule comes from checkpolicy, which the base image does not ship.
# Installed here, by the only thing that calls it, rather than up front
# for every image whether or not one compiles policy. Guarded, so a
# module with several .te files pays for one dnf5 transaction and a later
# layer that inherits the package pays for none.
ensure_checkpolicy() {
    command -v checkmodule > /dev/null 2>&1 || dnf5 install -y checkpolicy
}

# <te-file> — compiles the .te source and installs it into the targeted
# store at priority 200. -n skips the policy reload, which can't happen in
# a container build. Cleans up the .te and intermediate files.
install_selinux_module() {
    local te="$1"
    local base="${te%.te}"
    ensure_checkpolicy
    checkmodule -M -m -o "${base}.mod" "$te"
    semodule_package -o "${base}.pp" -m "${base}.mod"
    semodule -n -s targeted -X 200 -i "${base}.pp"
    rm -f "$te" "${base}.mod" "${base}.pp"
}
