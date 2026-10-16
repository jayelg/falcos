# nvidia

The NVIDIA proprietary host driver, built for the image kernel and
MOK-signed. The card stays with the host; consumers like
`virtualization/virtio-nvgpu` share it, and a passthrough domain detaches
it through libvirt's managed hostdev.

## What this module installs

- **The driver at 615.71.09**, from NVIDIA's CUDA repo. The CUDA repo and
  not the multimedia one: 615.71.09 is the release the virtio-nvgpu
  backend has an exact ABI and video-memory profile for, so the per-VM
  VRAM limit works and no RM control falls back to an older release's
  table. Kernel modules are built for the image kernel from the DKMS
  package's source and MOK-signed with the same key the DKMS modules use.
- **A fileless `nvidia-kmod` stub** (`nvidia-kmod-stub.rpm`, spec in its
  description) and the userspace half: `nvidia-kmod-common` carries the
  udev rules that create `/dev/nvidia*`, the modprobe config and the
  firmware; `nvidia-driver-cuda` brings `nvidia-smi`. The stub keeps the
  multi-gigabyte DKMS source package and its toolchain out of the image.
- **The graphics userspace** (`nvidia-driver-libs`): EGL, GLX, GLES,
  Vulkan and the GBM backend, which the compute half does not carry and
  which a rendering container (Wolf) needs.
- **`/usr/lib64/nvidia-gow/`**, the driver libraries collected into the
  layout NVIDIA's own `.run` installer produces (`lib/`, `lib/gbm/`,
  `share/{vulkan,glvnd,egl}/`). A GOW image links the driver from
  `/usr/nvidia`; mounting this tree there gives it the host's driver
  without building upstream's `nvidia-driver` image at runtime. See
  `hardware/wolf`.
- **`modules-load.d/nvidia.conf`**, which loads `nvidia_drm` and
  `nvidia_uvm` at boot: neither has a PCI alias for udev to load it by,
  and `nvidia-modprobe` only creates them on demand mid-open, so a
  consumer that opens the card at boot needs them present.

## Relationship with the GPU-sharing and passthrough modules

This module owns the card's binding. `virtualization/virtio-nvgpu` shares
the card this driver holds and requires the Secure Boot cert this module
provides. `virtualization/vfio-passthrough` is `iommu=pt` only: VMware
passthrough domains bind `vfio-pci` per VM through libvirt's managed
hostdev entries, which detach the card from this driver on start and give
it back on stop. The sharing guests and a passthrough domain cannot use
the card at once.

**Requires:** `--mount=type=secret,id=mok_privkey` for Secure Boot module
signing (optional; without it the modules build unsigned and will not load
under Secure Boot). Must run after the kernel provider so the modules build
against the image kernel.
