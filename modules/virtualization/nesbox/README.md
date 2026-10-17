# nesbox

The microVM VMM for [`virtualization/virtio-nvgpu`](../virtio-nvgpu),
built from [nestrilabs/nesbox](https://github.com/nestrilabs/nesbox) at
v0.3.1. It carries the virtio-nvgpu device and the two vhost-user
shared-memory regions the guest maps, so the GPU-sharing path needs no
QEMU and no QEMU upgrade.

`virtualization/libvirt` keeps stock QEMU for ordinary full VMs. This
module is gated to the desktop flavor and requires the virtio-nvgpu
backend and its `nvgpu@.service`.

## What this module installs

- **`/usr/libexec/nvgpu/nesbox`**, built with upstream's `virgl` feature
  off. This host forwards NVIDIA ioctls; it must not link virglrenderer or
  a Mesa stack it will never call. Upstream v0.3.1 has one unguarded
  `stats` module that imports virtio-gpu types behind `virgl`, so the
  build applies a one-line patch (`nesbox-no-virgl-stats.patch`) until a
  tag includes the fix.
- **`nesbox@.service`**, one instance per config:
  `/etc/nesbox/NAME.json`. It `BindsTo` `nvgpu@NAME.service`, so the
  backend is up and its socket exists before nesbox connects. Stopping
  `nesbox@NAME` stops the backend too.
- **`nvgpu-create-microvm`**, which writes the config and prints the unit
  to start. A goojust recipe with the same prompts is in the
  `Virtualization` menu.

## Creating a guest

The guest must be a `vmlinux` and a rootfs image, not a UKI. Nesbox enters
through the PVH entry point, so the kernel needs `CONFIG_PVH`, plus
`VIRTIO_PCI`, `PCI_MMCONFIG`, virtio block and DRM. Inside the guest, run
`/usr/share/nvgpu/fedora-guest-setup.sh` (shipped by
`virtualization/virtio-nvgpu`) to install NVIDIA's user-mode driver and
build `virtio_gpu_nv` against the guest kernel.

```
nvgpu-create-microvm NAME /path/to/vmlinux /path/to/rootfs.ext4
systemctl start nesbox@NAME
```

The helper writes `gpu-forward.socket=/run/nvgpu/NAME.sock` and nothing
else. Add `network`, `shared-directories` or `stats-socket` to the JSON
by hand if the guest needs them; `stats-socket` is refused by this
no-virgl build. Network taps are not created here -- upstream's
`scripts/nestri-net-setup.sh` sets up the bridge and taps on the host.

The guest's VRAM cap is the backend's `NVGPU_VRAM_LIMIT_MIB` in
`/usr/lib/nvgpu/backend.env` (overridable in `/etc/nvgpu/backend.env`).
Do not set a different `vram-limit-mib` in the nesbox config: nesbox
checks the two agree and refuses the guest if they do not.

## Limitations

nesbox is early: JSON config only, no management API, no snapshots or
live migration. It boots one guest per process. The GPU is shared through
the host driver, not isolated by the IOMMU; see the
[virtio-nvgpu security notes](../virtio-nvgpu/README.md).
