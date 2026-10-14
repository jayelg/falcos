### virtio-nvgpu: the host keeps the GPU, many VMs share it.
#
# Three pieces: the NVIDIA driver (615.71.09, built for the image kernel
# and MOK-signed), QEMU with the vhost-user shared-memory protocol the
# device needs, and the vhost-user-nvgpu backend at a pinned commit.

source /ctx/lib/kernel-helpers.sh
source /ctx/lib/sign-helpers.sh

CUDA_REPO="cuda-fedora44-x86_64"
NVVER="615.71.09"
VIRT_PREVIEW="copr:copr.fedorainfracloud.org:group_virtmaint-sig:virt-preview"

### QEMU with vhost-user shared memory
#
# Fedora 44's QEMU predates VHOST_USER_PROTOCOL_F_SHMEM. Without it the
# device has no shared-memory window, the guest driver cannot map GPU
# memory and the whole point is lost -- and the failure would surface at
# VM start, long after this build. virt-preview carries the newer QEMU;
# the version floor is asserted below so a silent downgrade stops the
# build here instead.
dnf5 --enablerepo="$VIRT_PREVIEW" upgrade -y "qemu*"

installed_qemu="$(rpm -q --qf '%{VERSION}' qemu-system-x86-core)"
if [ "$(printf '%s\n%s\n' 11.1.2 "$installed_qemu" | sort -V | head -1)" != 11.1.2 ]; then
	echo "qemu ${installed_qemu} predates vhost-user SHMEM; virt-preview did not upgrade it" >&2
	exit 1
fi
/usr/bin/qemu-system-x86_64 -device help 2>/dev/null | grep -q "vhost-user-test-device-pci" || {
	echo "qemu has no generic vhost-user device; the backend cannot attach" >&2
	exit 1
}

### The NVIDIA driver, 615.71.09
#
# NVIDIA's CUDA repo, not the multimedia one. 615.71.09 is the newest
# release the backend has an exact ABI and video-memory profile for --
# the per-VM VRAM limit works, and no RM control falls back to an older
# release's table. The multimedia repo's newer 615.78.08 also oopses in
# nv_audio_dynamic_power when a display attached to the card goes through
# a modeset (measured on this machine, twice: the RTX's HDMI monitor,
# with and without nvidia-drm KMS); 615.71.09 was verified live on the
# same machine to load, initialize, and drive the display cleanly.
#
# The repo key is imported explicitly: dnf5 in a build layer has no one
# to answer its key prompt.
rpm --import https://developer.download.nvidia.com/compute/cuda/repos/fedora44/x86_64/73CD9B30.pub

# nvidia-kmod-common -- the udev rules, modprobe config and firmware --
# requires nvidia-kmod, and the repo's only provider is the DKMS package:
# a multi-gigabyte source tree plus dkms plus a compiler toolchain, none
# of which belongs in an image that builds its own modules from that
# source. The fileless stub beside this script -- same name, same EVR --
# satisfies the requirement, so the userspace resolves without it. Its
# spec travels in the stub's description.
dnf5 install -y "$MODDIR/nvidia-kmod-stub.rpm"
dnf5 --enablerepo="$CUDA_REPO" install -y --setopt=install_weak_deps=False \
	"nvidia-kmod-common-${NVVER}" \
	"nvidia-driver-common-${NVVER}" \
	"nvidia-driver-cuda-${NVVER}"

# The shipped config enables S0ix audio power management, which a desktop
# has no use for and which gates the audio-power path involved in the
# 615.78.08 crash. Deterministically off, in the file this layer now
# owns.
sed -i 's/^options nvidia NVreg_EnableS0ixPowerManagement=1$/options nvidia NVreg_EnableS0ixPowerManagement=0/' \
	/usr/lib/modprobe.d/nvidia.conf
grep -q '^options nvidia NVreg_EnableS0ixPowerManagement=0$' /usr/lib/modprobe.d/nvidia.conf || {
	echo "nvidia.conf: the S0ix line moved; fix the sed" >&2
	exit 1
}

# Kernel modules: built from the DKMS package's source for the image
# kernel. uname inside a build container reports the build host's kernel,
# not the image's, so KERNEL_UNAME names the kernel explicitly -- which
# is also exactly how the package's own dkms.conf builds it.
KVER="$(kver)"
dnf5 install -y kernel-devel-matched gcc gcc-c++ make elfutils-libelf-devel cpio
dnf5 --enablerepo="$CUDA_REPO" download --destdir=/tmp/nvsdk "kmod-nvidia-open-dkms-${NVVER}"
(
	cd /tmp/nvsdk || exit 1
	rpm2cpio ./*.rpm | cpio -idm --quiet
)
srcdir="$(find /tmp/nvsdk -maxdepth 4 -type d -name 'nvidia-*' | head -1)"
[ -n "$srcdir" ] || {
	echo "no driver source tree in the downloaded package" >&2
	exit 1
}
make -C "$srcdir" modules -j"$(nproc)" KERNEL_UNAME="$KVER"

install -d "/usr/lib/modules/${KVER}/extra/nvidia"
install -m 0644 "$srcdir"/kernel-open/*.ko "/usr/lib/modules/${KVER}/extra/nvidia/"
depmod -a "$KVER"
rm -rf /tmp/nvsdk

# The signing cert has to exist before sign-helpers.sh is asked whether
# signing is possible: its files/ overlay copy lands after this script
# runs, so it is installed from the module directory first, the same
# shape as the kernel module's install of the same file.
install -Dm644 "$MODDIR/files/usr/share/nvgpu/sb_cert.der" /usr/share/secureboot/sb_cert.der
if mok_signing_available; then
	while IFS= read -r ko; do
		[ -n "$(modinfo -F signer "$ko" 2>/dev/null)" ] && continue
		sign_kernel_module "$ko" "/usr/src/kernels/${KVER}/scripts/sign-file"
	done < <(find "/usr/lib/modules/${KVER}/extra" -name "nvidia*.ko*" 2>/dev/null)
else
	echo "No MOK key supplied: NVIDIA modules will be unsigned and will not load under Secure Boot."
fi

# The driver is built; the build toolchain goes back out. Safe now that
# nothing else depends on it: dkms never entered the image (the stub kept
# it out), and cpio deliberately stays -- it is a dracut dependency and
# removing it once uninstalled dracut, bootc and rpm-ostree in one
# cascade. The kmod-common package stays: it is where the udev rules, the
# modprobe config and the firmware live.
dnf5 remove -y --noautoremove kernel-devel-matched kernel-devel gcc gcc-c++ make elfutils-libelf-devel

### The vhost-user-nvgpu backend
dnf5 install -y cargo rust patch git

git clone --quiet https://github.com/nestrilabs/virtio-nvgpu.git /tmp/virtio-nvgpu
git -C /tmp/virtio-nvgpu checkout --quiet "$ASSET_VIRTIO_NVGPU_VERSION"
if [ "$(git -C /tmp/virtio-nvgpu rev-parse HEAD)" != "$ASSET_VIRTIO_NVGPU_VERSION" ]; then
	echo "virtio-nvgpu checkout did not land on the pinned commit" >&2
	exit 1
fi
git -C /tmp/virtio-nvgpu apply "$MODDIR/patches/0001-vhost-user-answer-GET_SHMEM_CONFIG.patch"

(cd /tmp/virtio-nvgpu && cargo build --release --locked --features vhost-user -p device --bin vhost-user-nvgpu)
install -D -m 0755 /tmp/virtio-nvgpu/target/release/vhost-user-nvgpu /usr/libexec/nvgpu/vhost-user-nvgpu
rm -rf /tmp/virtio-nvgpu

dnf5 remove -y --noautoremove cargo rust patch
