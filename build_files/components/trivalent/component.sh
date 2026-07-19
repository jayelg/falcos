# Trivalent, secureblue's hardened Chromium fork
# Phase: frequent
# Priority: 030 (after VPNs, before Affinity)
# Writable paths: /usr (dnf5-installed packages)

COMPDIR="$(dirname "${BASH_SOURCE[0]}")"

# COMPONENT_VERSION is set by the Containerfile RUN instruction from COMPONENTS.list.
COMPONENT_VERSION="${COMPONENT_VERSION:-latest}"

# If a versioned subdirectory exists, switch into it.
if [ -d "$COMPDIR/$COMPONENT_VERSION" ]; then
    COMPDIR="$COMPDIR/$COMPONENT_VERSION"
fi

# Has its own hardened_malloc integration so it needs no LD_PRELOAD
# exemption. Not version-pinned, upstream ships new builds continuously.
dnf5 install -y --enablerepo='secureblue' trivalent trivalent-qt6-ui trivalent-selinux

# Local supplement to the packaged trivalent-selinux policy: rules its
# bwrap fallback sandbox needs that upstream doesn't yet grant. The
# method_start_transient_unit denial is a separate open upstream bug
# (secureblue/Trivalent#507) and is deliberately not fixed here. Boot-test
# after Trivalent or kernel/systemd updates.
cat <<'EOF' > /tmp/trivalent_local_fixes.te
module trivalent_local_fixes 1.0;

require {
	type unconfined_trivalent_t;
	type unconfined_trivalent_script_t;
	type cgroup_t;
	type fusefs_t;
	type proc_t;
	type sysctl_dev_t;
	type unconfined_t;
	class filesystem { remount associate };
	class dir search;
}

allow unconfined_trivalent_script_t cgroup_t:filesystem remount;
allow unconfined_trivalent_script_t fusefs_t:filesystem remount;
allow unconfined_trivalent_script_t proc_t:filesystem associate;

allow unconfined_trivalent_t sysctl_dev_t:dir search;
allow unconfined_trivalent_t unconfined_t:dir search;
EOF
source /ctx/lib/selinux-helpers.sh
install_selinux_module /tmp/trivalent_local_fixes.te

# Install overlay files into the image
[ -d "$COMPDIR/files" ] && cp -rT "$COMPDIR/files" "/"

# Append runtime justfile recipes to the shared app-recipes file
if [ -f "$COMPDIR/justfile.inc" ]; then
    cat "$COMPDIR/justfile.inc" >> /usr/share/falcos/justfile.apps
fi
