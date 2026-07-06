### Hardening
# Cherry-picked from secureblue. Drop-in configs live under files/common/etc/
# (already copied in); their systemctl mask/enable calls live in
# enable-services.sh since systemctl is stubbed out here.

### hardened_malloc — GrapheneOS's hardened allocator
dnf5 -y copr enable secureblue/packages
dnf5 -y install --enablerepo="copr:copr.fedorainfracloud.org:secureblue:packages" \
    hardened_malloc \
    no_rlimit_as
dnf5 -y copr disable secureblue/packages
# Wired system-wide via files/common/etc/environment.d/30-hardened-malloc.conf.
# Apps expecting a larger address space than its default RLIMIT_AS allows
# (JVMs, emulators, Wine/Proton) can also LD_PRELOAD libno_rlimit_as.so, or
# opt out entirely with `env -u LD_PRELOAD <command>`.

### DNS-over-TLS
# dnsconfd reconfigures unbound to match whatever DNS NetworkManager
# reports, including VPN-pushed servers (Mullvad/Tailscale/Netbird),
# upgrading to DoT only where supported. No hardcoded upstream resolver, or
# it would override VPN-pushed DNS.
dnf5 -y install unbound dnsconfd

# 99-hardening isn't copied from files/common until phase-finalize.sh (see
# Containerfile) — this needs its 0440 mode now (git can't track that), so
# install it directly from its own narrow mount instead.
install -Dm440 /ctx/files/99-hardening /etc/sudoers.d/99-hardening

### Electron apps vs hardened_malloc
# codium is exempted from the LD_PRELOAD above (see common/frequent/000-pinned-tools.sh)
# — it doesn't exist yet at this point in the build for this script to wrap.
