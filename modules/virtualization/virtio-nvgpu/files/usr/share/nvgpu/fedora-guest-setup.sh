#!/bin/bash
# Guest-side setup for a Fedora microVM sharing the host's GPU via
# virtio-nvgpu (run inside the VM):
#
#   sudo bash nvgpu-fedora-guest-setup.sh
#
# Installs NVIDIA's user-mode driver at the version the host kernel module
# runs (615.71.09 -- they must match), builds the virtio_gpu_nv module
# against the running guest kernel, loads it, and smoke-tests the GPU.
# The VMM is virtualization/nesbox, not QEMU.
# Deliberately no NVIDIA kernel modules: the virtio driver replaces them.
# Rerun after every guest kernel update.
set -euo pipefail
if [ "$(id -u)" != 0 ]; then exec sudo bash "$0" "$@"; fi

NVVER=615.71.09
RELVER=$(rpm -E %fedora)
REPO="https://developer.download.nvidia.com/compute/cuda/repos/fedora${RELVER}/x86_64"
STUB_URL="https://raw.githubusercontent.com/jayelg/falcos/main/modules/hardware/nvidia/nvidia-kmod-stub.rpm"
SRC=/usr/local/src/virtio-nvgpu

echo "== NVIDIA CUDA repo for Fedora $RELVER"
curl -fsI "$REPO/repodata/repomd.xml" >/dev/null || {
    echo "no NVIDIA CUDA repo for fedora${RELVER} yet" >&2; exit 1; }
rpm --import "$REPO/73CD9B30.pub"
cat > /etc/yum.repos.d/cuda-nvidia.repo <<EOF
[cuda-nvidia]
name=NVIDIA CUDA (fedora${RELVER}-x86_64)
baseurl=$REPO
enabled=1
gpgcheck=1
gpgkey=$REPO/73CD9B30.pub
EOF

echo "== nvidia-kmod stub (keeps the DKMS kernel-module chain out)"
curl -fsSL -o /tmp/nvidia-kmod-stub.rpm "$STUB_URL"
dnf install -y /tmp/nvidia-kmod-stub.rpm

echo "== NVIDIA user-mode driver $NVVER (must match the host kernel module)"
dnf install -y --setopt=install_weak_deps=False \
    "nvidia-kmod-common-${NVVER}" \
    "nvidia-driver-common-${NVVER}" \
    "nvidia-driver-cuda-${NVVER}" \
    "nvidia-driver-libs-${NVVER}" \
    vulkan-tools

echo "== build tooling + kernel headers for $(uname -r)"
if ! dnf install -y "kernel-devel-$(uname -r)" gcc make git; then
    echo "kernel-devel for $(uname -r) is not installable; update the kernel, reboot, and rerun" >&2
    exit 2
fi

echo "== building virtio_gpu_nv.ko against $(uname -r) (vermagic must match)"
rm -rf "$SRC"
# Keep this tag in step with the backend pin in module.kdl.
git clone --quiet --depth 1 --branch v0.2.1 \
    https://github.com/nestrilabs/virtio-nvgpu "$SRC"
make -C "$SRC/driver" KDIR="/lib/modules/$(uname -r)/build"
install -D -m 0644 "$SRC/driver/virtio_gpu_nv.ko" \
    "/lib/modules/$(uname -r)/extra/virtio_gpu_nv.ko"
depmod -a

# Secure Boot rejects an unsigned module, so sign with the enrolled guest MOK.
if [ -f /var/lib/nvgpu-mok/MOK.priv ] && [ -f /var/lib/nvgpu-mok/MOK.der ]; then
    echo "== signing with the guest MOK"
    "/usr/src/kernels/$(uname -r)/scripts/sign-file" sha512 \
        /var/lib/nvgpu-mok/MOK.priv /var/lib/nvgpu-mok/MOK.der \
        "/lib/modules/$(uname -r)/extra/virtio_gpu_nv.ko"
fi

echo "== loading"
modprobe virtio_gpu_nv
sleep 1
ls -l /dev/nvidia* 2>&1 || true

echo "== smoke tests"
nvidia-smi
if command -v vulkaninfo >/dev/null; then vulkaninfo --summary 2>&1 | sed -n '1,40p'; fi

touch /var/log/nvgpu-ok
echo "DONE: the shared GPU is live in this VM. Rerun after a guest kernel update."
