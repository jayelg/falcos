### hardened_malloc, GrapheneOS's hardened allocator
# System-wide LD_PRELOAD set via files/common/etc/environment.d/30-hardened-malloc.conf.
# Apps that break under it are wrapped at install time or exempted at runtime.
dnf5 install -y --enablerepo='secureblue' hardened_malloc no_rlimit_as
