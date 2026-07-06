### Trivalent — Chromium fork with hardened_malloc integration, so it
# doesn't need the LD_PRELOAD exemption a generic Chromium/Electron build
# would (see common/core/130-hardening.sh). Not version-pinned — it ships
# new builds almost continuously, which is exactly why this lives in the
# frequent layer rather than common/core (kde-desktop group + generic
# browser integration), not because it's tracked by Renovate.
dnf5 install -y --enablerepo='secureblue' trivalent trivalent-qt6-ui trivalent-selinux

# Local supplement to upstream's packaged trivalent-selinux policy: covers
# rules its bwrap fallback sandbox needs but the current upstream policy
# (secureblue/Trivalent build/selinux/trivalent.te) doesn't yet grant,
# found by comparing installed AVC denials against that source. Scoped to
# the unconfined role — the only one this single-user desktop image uses.
#
# Deliberately NOT fixed here: the method_start_transient_unit denial seen
# alongside these — that's a separate, open upstream bug
# (secureblue/Trivalent#507) with no accepted fix yet, and Trivalent already
# falls back to bwrap sandboxing without it. Boot-test after any Trivalent
# or kernel/systemd update to confirm these are still needed/sufficient.
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
checkmodule -M -m -o /tmp/trivalent_local_fixes.mod /tmp/trivalent_local_fixes.te
semodule_package -o /tmp/trivalent_local_fixes.pp -m /tmp/trivalent_local_fixes.mod
semodule -n -s targeted -X 200 -i /tmp/trivalent_local_fixes.pp
rm -f /tmp/trivalent_local_fixes.te /tmp/trivalent_local_fixes.mod /tmp/trivalent_local_fixes.pp
