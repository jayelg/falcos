### Hardening, cherry-picked from secureblue

### hardened_malloc, GrapheneOS's hardened allocator
# Wired system-wide via files/common/etc/environment.d/30-hardened-malloc.conf.
# Apps that break under it are wrapped with `env -u LD_PRELOAD` where they
# are installed, or at runtime via `ujust hardened-malloc-exempt`.
dnf5 -y copr enable secureblue/packages
dnf5 -y install --enablerepo="copr:copr.fedorainfracloud.org:secureblue:packages" \
    hardened_malloc \
    no_rlimit_as
dnf5 -y copr disable secureblue/packages

# Installed directly rather than via the files/common copy since git can't
# track the 0440 mode sudo requires
install -Dm440 /ctx/files/99-hardening /etc/sudoers.d/99-hardening
