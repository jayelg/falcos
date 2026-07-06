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
    qemu-user-static       # static qemu binaries for cross-arch emulation/builds
    slirp4netns            # userspace networking for rootless containers
    systemd-container      # systemd-nspawn and friends
    virt-manager
    virt-v2v               # convert VMs from other hypervisors
    virt-viewer
)
dnf5 install -y "${VIRT_PACKAGES[@]}"
