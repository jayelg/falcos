# Trivalent, secureblue's hardened Chromium fork

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
