### virtio-nvgpu: the host keeps the GPU, microVMs share it.
#
# This module installs only the host backend. The VMM is
# virtualization/nesbox: it has the virtio-nvgpu device and the two
# vhost-user shared-memory regions the guest maps (the device window and
# the UVM aperture). QEMU's stock microvm transport has neither, so the
# full-VM path this module used to carry is gone; QEMU stays stock for
# libvirt guests, which reach a GPU through vfio-passthrough instead.

### The vhost-user-nvgpu backend
dnf5 install -y cargo rust git

# Upstream publishes tags but no release archives, so the pin is the tag
# itself: the checkout is the content and there is no url or sha256 to
# declare. --locked keeps the dependency set the tag was tested with.
git clone --quiet --depth 1 --branch "$ASSET_VIRTIO_NVGPU_VERSION" \
	https://github.com/nestrilabs/virtio-nvgpu /tmp/virtio-nvgpu
(cd /tmp/virtio-nvgpu && cargo build --release --locked --features vhost-user -p device --bin vhost-user-nvgpu)
install -D -m 0755 /tmp/virtio-nvgpu/target/release/vhost-user-nvgpu /usr/libexec/nvgpu/vhost-user-nvgpu
rm -rf /tmp/virtio-nvgpu

# git stays: dev-tools provides it, and removing it here would take it
# from every other consumer in the image.
dnf5 remove -y --noautoremove cargo rust
