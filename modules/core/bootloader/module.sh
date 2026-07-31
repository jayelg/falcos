### Dual boot
# Let GRUB's config generator run os-prober, so other installed OSes get
# boot menu entries. os-prober only runs when grub.cfg is regenerated,
# which is the recipe this module ships rather than anything automatic.
echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
