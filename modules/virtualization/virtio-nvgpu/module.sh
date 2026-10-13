### virtio-nvgpu: the host keeps the GPU, many VMs share it.
#
# Three pieces: the NVIDIA driver (akmods, built for the image kernel and
# MOK-signed), QEMU with the vhost-user shared-memory protocol the device
# needs, and the vhost-user-nvgpu backend at a pinned commit.

source /ctx/lib/kernel-helpers.sh
source /ctx/lib/sign-helpers.sh

VIRT_PREVIEW="copr:copr.fedorainfracloud.org:group_virtmaint-sig:virt-preview"
FEDORA_MULTIMEDIA="fedora-multimedia"

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

### The NVIDIA driver
#
# kernel-devel-matched matches the kernel the image ships, and --kernels
# names that kernel explicitly: uname inside a build container reports the
# build host's kernel, not the image's, and akmods defaults to uname.
dnf5 --enablerepo="$FEDORA_MULTIMEDIA" install -y \
	kernel-devel-matched akmods kmodtool gcc-c++ elfutils-libelf-devel make \
	akmod-nvidia nvidia-kmod-common nvidia-driver-common nvidia-driver-cuda

KVER="$(kver)"
# The cert has to exist before sign-helpers.sh is asked whether signing is
# possible: its files/ overlay copy lands after this script runs, so it is
# installed from the module directory first, the same shape as the kernel
# module's install of the same file.
install -Dm644 "$MODDIR/files/usr/share/nvgpu/sb_cert.der" /usr/share/secureboot/sb_cert.der
if mok_signing_available; then
	# akmodsbuild runs as the akmods user (akmods' own runuser call), so
	# the key material is group-readable by akmods -- the shape kmodgenca
	# produces, which is also why without it the build fails outright
	# rather than producing unsigned modules. Removed again below so the
	# private key never reaches the image.
	install -d -m 0750 /etc/pki/akmods/private /etc/pki/akmods/certs
	install -m 0640 -o root -g akmods "$MOK_KEY" /etc/pki/akmods/private/private_key.priv
	install -m 0644 -o root -g akmods "$MOK_CERT_DER" /etc/pki/akmods/certs/public_key.der
	chown root:akmods /etc/pki/akmods/private /etc/pki/akmods/certs
else
	echo "No MOK key supplied: NVIDIA modules will be unsigned and will not load under Secure Boot."
fi

akmods --force --kernels "$KVER"

# Belt for an akmods that does not sign on its own: sign whatever came out
# unsigned. A missing signature only shows at boot, as a module that never
# loads.
if mok_signing_available; then
	while IFS= read -r ko; do
		[ -n "$(modinfo -F signer "$ko" 2>/dev/null)" ] && continue
		sign_kernel_module "$ko" "/usr/src/kernels/${KVER}/scripts/sign-file"
	done < <(find "/usr/lib/modules/${KVER}/extra" -name "nvidia*.ko*" 2>/dev/null)
fi
rm -rf /etc/pki/akmods

# The driver is built; none of this can run again on a bootc image, where
# the next kernel arrives in a next image and rebuilds this layer.
# --noautoremove keeps nvidia-kmod-common: it is where the udev rules,
# modprobe config and firmware blobs live.
dnf5 remove -y --noautoremove \
	kernel-devel-matched akmods kmodtool gcc-c++ elfutils-libelf-devel make akmod-nvidia
rm -rf /var/cache/akmods

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
