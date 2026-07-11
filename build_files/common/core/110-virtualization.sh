### Virtualization + containers
VIRT_PACKAGES=(
    edk2-ovmf              # UEFI firmware for VMs
    incus                  # LXC/VM manager (alternative to libvirt)
    incus-agent
    libvirt
    libvirt-nss            # resolve libvirt VM hostnames via NSS
    lxc
    podman-compose
    podman-machine
    podman-tui
    qemu
    qemu-img
    qemu-system-x86-core
    qemu-user-binfmt       # register qemu with binfmt_misc for foreign-arch binaries
    qemu-user-static-aarch64  # static qemu for aarch64 emulation/builds; the
                              # qemu-user-static meta-package would reinstall every
                              # exotic arch trimmed in 010-kde-desktop.sh
    slirp4netns            # userspace networking for rootless containers
    systemd-container      # systemd-nspawn and friends
    virt-manager
    virt-v2v               # convert VMs from other hypervisors
    virt-viewer
)
dnf5 install -y "${VIRT_PACKAGES[@]}"

### virt-manager hardened_malloc exemption
if [ -f /usr/bin/virt-manager ] && [ ! -f /usr/bin/virt-manager.bin ]; then
    mv /usr/bin/virt-manager /usr/bin/virt-manager.bin
    cat > /usr/bin/virt-manager <<'EOF'
#!/bin/bash
exec env -u LD_PRELOAD /usr/bin/virt-manager.bin "$@"
EOF
    chmod 755 /usr/bin/virt-manager
fi
