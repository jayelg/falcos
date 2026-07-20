# Trivalent, secureblue's hardened Chromium fork

# Has its own hardened_malloc integration so it needs no LD_PRELOAD
# exemption. Not version-pinned, upstream ships new builds continuously.
dnf5 install -y --enablerepo='secureblue' trivalent trivalent-qt6-ui trivalent-selinux

# Local supplement to the packaged trivalent-selinux policy lives in
# selinux/trivalent_local_fixes.te (auto-compiled + installed by
# run-component.sh): rules its bwrap fallback sandbox needs that upstream
# doesn't yet grant. The method_start_transient_unit denial is a separate
# open upstream bug (secureblue/Trivalent#507) and is deliberately not fixed
# there. Boot-test after Trivalent or kernel/systemd updates.
