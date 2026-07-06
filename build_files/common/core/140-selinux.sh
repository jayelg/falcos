### SELinux policy: composefs/overlay execmem workaround
# Allows kernel_t self execmem — works around a Linux 7.0 composefs/overlay
# mmap bug that mislabels legitimate userspace execmem mappings as kernel_t.
# https://github.com/ublue-os/akmods/issues/537
#
# Tied to the kernel build, not "Linux 7.0" generically — boot-test after
# any kernel change (common/core/060-cachyos-kernel.sh) to confirm it still
# applies. TODO: drop once ublue-os/akmods#537 is fixed upstream.
cat <<'EOF' > /tmp/composefs_execmem.te
module composefs_execmem 0.1;

require {
	type kernel_t;
	class process execmem;
}

allow kernel_t self:process execmem;
EOF
checkmodule -M -m -o /tmp/composefs_execmem.mod /tmp/composefs_execmem.te
semodule_package -o /tmp/composefs_execmem.pp -m /tmp/composefs_execmem.mod
semodule -n -s targeted -X 200 -i /tmp/composefs_execmem.pp
rm -f /tmp/composefs_execmem.te /tmp/composefs_execmem.mod /tmp/composefs_execmem.pp
