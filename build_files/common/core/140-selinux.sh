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
source /ctx/lib/selinux-helpers.sh
install_selinux_module /tmp/composefs_execmem.te
