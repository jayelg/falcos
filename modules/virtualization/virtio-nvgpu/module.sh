### virtio-nvgpu: the host keeps the GPU, many VMs share it.
#
# Two pieces: a QEMU with the vhost-user shared-memory protocol the
# device needs, and the vhost-user-nvgpu backend at a pinned commit. The
# NVIDIA host driver is hardware/nvidia, built for the image kernel and
# MOK-signed; this module shares it.

### QEMU with vhost-user shared memory
#
# Fedora 44's QEMU predates VHOST_USER_PROTOCOL_F_SHMEM. Without it the
# device has no shared-memory window, the guest driver cannot map GPU
# memory and the whole point is lost -- and the failure would surface at
# VM start, long after this build. virt-preview carries the newer QEMU;
# the version floor is asserted below so a silent downgrade stops the
# build here instead.
VIRT_PREVIEW="copr:copr.fedorainfracloud.org:group_virtmaint-sig:virt-preview"
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

### The vhost-user-nvgpu backend
dnf5 install -y cargo rust patch git

# The pin is on the johngrantdev fork's stock-qemu branch until the
# branch merges upstream; switch this URL back to nestrilabs with that
# merge.
git clone --quiet --branch stock-qemu https://github.com/johngrantdev/virtio-nvgpu.git /tmp/virtio-nvgpu
git -C /tmp/virtio-nvgpu checkout --quiet "$ASSET_VIRTIO_NVGPU_VERSION"
if [ "$(git -C /tmp/virtio-nvgpu rev-parse HEAD)" != "$ASSET_VIRTIO_NVGPU_VERSION" ]; then
	echo "virtio-nvgpu checkout did not land on the pinned commit" >&2
	exit 1
fi

(cd /tmp/virtio-nvgpu && cargo build --release --locked --features vhost-user -p device --bin vhost-user-nvgpu)
install -D -m 0755 /tmp/virtio-nvgpu/target/release/vhost-user-nvgpu /usr/libexec/nvgpu/vhost-user-nvgpu
rm -rf /tmp/virtio-nvgpu

dnf5 remove -y --noautoremove cargo rust patch
