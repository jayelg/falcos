# virtio-nvgpu

Share one NVIDIA GPU across several microVMs while the host keeps the card,
through [virtio-nvgpu](https://github.com/nestrilabs/virtio-nvgpu). The
host runs NVIDIA's own driver and a per-VM backend process; each guest
runs the real NVIDIA user-mode driver on top of the `virtio_gpu_nv`
kernel module, which relays ioctls to the backend and maps GPU memory
straight into the guest.

This module installs the **host backend and the guest setup only**. The
VMM is [`virtualization/nesbox`](../nesbox): it carries the virtio-nvgpu
device and the two vhost-user shared-memory regions the guest maps -- the
device window and the CUDA aperture. QEMU is deliberately not involved:
its stock microvm transport has no shared-memory regions, so the old
full-VM path needed a newer QEMU for every consumer. QEMU and libvirt
stay stock for full VMs, which reach a GPU through
[`virtualization/vfio-passthrough`](../vfio-passthrough) instead.

**Linux guests only.** Upstream ships no Windows driver and the design
relays the Linux driver ABI. **Not hardware isolation**: the host driver
is the trust boundary, the same as the Docker-container level, not the
IOMMU level -- see upstream's SECURITY.md. Don't share the card between
tenants that don't trust each other.

## What this module installs

- **The `vhost-user-nvgpu` backend** built from the upstream
  [v0.2.1](https://github.com/nestrilabs/virtio-nvgpu/tree/v0.2.1) tag.
  The tag is the pin: upstream publishes no archives, so the checkout is
  its own integrity. The backend serves the window and the CUDA aperture
  through vhost-user shared memory, and enforces
  `--vram-limit-mib` per guest.
- **One backend per VM, on demand**: `nvgpu@.service` (a template unit),
  one unprivileged `nvgpu` user serving every instance. The unit starts
  from `/run/nvgpu/GUEST.sock`, requires `hardware/nvidia`'s
  `nvidia-nodes.service`, and hands the socket to the VMM.
- **`/usr/lib/nvgpu/backend.env`**, the default video-memory cap (4096
  MiB). Override per host in `/etc/nvgpu/backend.env`.
- **`/usr/share/nvgpu/fedora-guest-setup.sh`**, the guest-side installer
  for Fedora. It installs NVIDIA's user-mode driver at 615.71.09 -- the
  version the host kernel module runs -- builds `virtio_gpu_nv` against
  the guest's own kernel, loads it, and smoke-tests.

The **host driver** is `hardware/nvidia`: the backend opens the nodes it
created. This module requires the `nvidia-driver` capability it provides.

## How a microVM uses it

Use the [`virtualization/nesbox`](../nesbox) module. Its
`nvgpu-create-microvm` helper writes a config naming the guest `vmlinux`,
the rootfs and `/run/nvgpu/NAME.sock`; `systemctl start nesbox@NAME`
starts the backend and the VMM together.

The guest rootfs is not in this image. It runs the `virtio_gpu_nv` kernel
module (built against the guest's own kernel) plus NVIDIA's user-mode
driver at the same version as this image's kernel module, 615.71.09. No
NVIDIA kernel module goes in the guest -- that is what the virtio driver
replaces. For Fedora guests, copy `/usr/share/nvgpu/fedora-guest-setup.sh`
into the guest and run it with sudo; rerun it after every guest kernel
update. Other distros build the module by hand (`driver/README.md` in
the upstream repo).

The guest kernel needs `VIRTIO_PCI`, `PCI_MMCONFIG` and the usual virtio
block support; nesbox boots a `vmlinux` directly, so the guest must be
built as one (not a distro UKI).

## Relationship with vfio-passthrough

The two cannot share the card at once. This module needs the host driver
(`hardware/nvidia`) to own the GPU, and `virtualization/vfio-passthrough`
is `iommu=pt` only: passthrough domains bind `vfio-pci` per VM through
libvirt's managed hostdev entries (`managed='yes'`), which detach the card
from the host driver on start and give it back on stop. While virtio-nvgpu
guests are running the card is unavailable to passthrough domains (and the
other way around): stop the sharing guests before starting a passthrough
domain.
