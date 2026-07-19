### hardened_malloc, GrapheneOS's hardened allocator
# System-wide LD_PRELOAD set via files/common/etc/environment.d/30-hardened-malloc.conf.
# Apps that break under it are wrapped at install time or exempted at runtime.
# Uses the secureblue/packages COPR, separate from the secureblue repofile
# (components/apps/trivalent/repo) which carries trivalent.
dnf5 -y copr enable secureblue/packages
dnf5 -y copr disable secureblue/packages
dnf5 -y install --enablerepo="copr:copr.fedorainfracloud.org:secureblue:packages" \
    hardened_malloc \
    no_rlimit_as
