### SELinux policy: composefs/overlay execmem workaround
# A composefs/overlay mmap bug mislabels legitimate userspace execmem
# mappings as kernel_t (ublue-os/akmods#537). Boot-test after kernel
# changes; drop once fixed upstream.
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
