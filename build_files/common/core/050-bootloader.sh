### Dual-boot support
# os-prober is disabled by default upstream; enable it so GRUB detects
# other OSes (e.g. Windows).
if ! grep -q '^GRUB_DISABLE_OS_PROBER=false' /etc/default/grub 2>/dev/null; then
    echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
fi
