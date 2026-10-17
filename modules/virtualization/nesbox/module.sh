### nesbox: the microVM VMM the virtio-nvgpu backend was built for.
#
# Build with virgl off. This host forwards NVIDIA ioctls; it must not link
# virglrenderer or a Mesa stack it will never call. Upstream v0.3.1 gates
# the stats surface behind virgl everywhere but the module declaration,
# so the one-line patch below makes the no-virgl build compile. Remove it
# when a tag no longer needs it.
dnf5 install -y cargo rust git

git clone --quiet --depth 1 --branch "$ASSET_NESBOX_VERSION" \
	https://github.com/nestrilabs/nesbox /tmp/nesbox
git -C /tmp/nesbox apply "$MODDIR/nesbox-no-virgl-stats.patch"
# The tag's Cargo.lock still names the previous workspace version, so
# --locked would refuse the checked-out tree; Cargo updates that one entry
# and resolves the rest from the lock.
(cd /tmp/nesbox && cargo build --release --no-default-features -p nesbox-vmm --bin nesbox)
install -D -m 0755 /tmp/nesbox/target/release/nesbox /usr/libexec/nvgpu/nesbox
rm -rf /tmp/nesbox

# git stays: dev-tools provides it, and removing it here would take it
# from every other consumer in the image.
dnf5 remove -y --noautoremove cargo rust
