# libvirt:latest

libvirt virtualization stack with QEMU, virt-manager, and helper services.

**Packages:** edk2-ovmf, libvirt, libvirt-nss, qemu, qemu-img, qemu-system-x86-core, qemu-user-binfmt, qemu-user-static-aarch64, virt-manager, virt-v2v, virt-viewer

**Hardened malloc:** virt-manager is wrapped with `env -u LD_PRELOAD`.

**Files installed:**
- `usr/lib/systemd/system/libvirt-relabel.service`
- `usr/lib/systemd/system/libvirt-group-membership.service`
- `usr/lib/sysusers.d/libvirt-workarounds.conf`
- `usr/lib/tmpfiles.d/libvirt-workarounds.conf`
- `usr/libexec/add-wheel-users-to-libvirt`
