# virtio-nvgpu

Share one NVIDIA GPU across several VMs while the host keeps the card,
through [virtio-nvgpu](https://github.com/nestrilabs/virtio-nvgpu). The
host runs NVIDIA's own driver and a per-VM backend process; each guest
runs the real NVIDIA user-mode driver on top of the `virtio_gpu_nv`
kernel module, which relays ioctls to the backend and maps GPU memory
straight into the guest -- passthrough-grade speed without locking the
card to one VM and without vGPU licences.

**Linux guests only.** Upstream ships no Windows driver and the design
relays the Linux driver ABI, so a Windows guest cannot use it; Windows
and other passthrough domains keep using `virtualization/vfio-passthrough`.
**Not hardware isolation**: the host driver is the trust boundary, the
same as the Docker-container level, not the IOMMU level -- see upstream's
SECURITY.md. Don't share the card between tenants that don't trust each
other.

## What this module installs

- **The NVIDIA host driver** (`akmod-nvidia`) built for the image kernel
  and MOK-signed with the same key the DKMS modules use, plus
  `nvidia-driver-cuda` for `nvidia-smi`. The kmod's `nvidia-kmod-common`
  carries the udev rules that create `/dev/nvidia*`, the modprobe config
  and the firmware blobs.
- **QEMU with vhost-user shared memory.** Fedora 44's QEMU predates
  `VHOST_USER_PROTOCOL_F_SHMEM`; the device's memory window is built on
  it. Installed from the virt-preview COPR, version-floored at 11.1.2 in
  `module.sh`. Drop the repo and the floor once Fedora ships it.
- **The `vhost-user-nvgpu` backend** built from a pinned commit
  [21a4f075](https://github.com/nestrilabs/virtio-nvgpu/tree/21a4f075d5c01c0865c809a8592e40b860435768).
  The patch in `patches/` makes it answer QEMU's `GET_SHMEM_CONFIG`,
  which the `vhost-user-backend` trait default refuses and QEMU fails the
  device on. Upstream a fix here removes the patch.
- **One backend per VM, on demand**: `nvgpu@.service` (a template unit),
  started and stopped by the libvirt hook, one unprivileged `nvgpu` user
  serving every instance. No `--vram-limit-mib` is passed: the flag needs
  a video-memory table for the exact host release, and the image's
  615.78.08 has none, so the backend refuses it rather than guess. Guests
  share the card's full memory; per-guest caps return when a driver the
  backend knows is in the image.

## How a VM uses it

The domain must give guest RAM as a shared memfd and attach the backend
as QEMU's generic vhost-user device. The fragments that matter:

```xml
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
  ...
  <memoryBacking>
    <source type='memfd'/>
    <access mode='shared'/>
  </memoryBacking>
  ...
  <qemu:commandline>
    <qemu:arg value='-chardev'/>
    <qemu:arg value='socket,id=nvgpu,path=/run/nvgpu/GUEST.sock'/>
    <qemu:arg value='-device'/>
    <qemu:arg value='vhost-user-test-device-pci,virtio-id=45,num_vqs=2,vq_size=256,config_size=4096,chardev=nvgpu'/>
  </qemu:commandline>
</domain>
```

`GUEST` is the domain name: the hook starts `nvgpu@GUEST.service` for any
domain whose config contains `vhost-user-test-device`, waits for
`/run/nvgpu/GUEST.sock`, and relabels it `svirt_socket_t` so QEMU's
`svirt_t` may connect. On `stopped`/`release` the backend is stopped
again.

The **guest** side is not in this image: the guest runs the
`virtio_gpu_nv` kernel module (built from the upstream tree against the
guest's own kernel, `driver/README.md` in the repo covers it) plus
NVIDIA's user-mode driver at the same version as this image's kernel
module. No NVIDIA kernel module goes in the guest -- that is what the
virtio driver replaces.

## Relationship with vfio-passthrough

The two cannot share the card at once, and they disagree about who binds
it at boot. This module needs the host driver to own the GPU, so
`virtualization/vfio-passthrough` was reduced to `iommu=pt`: no more
`rd.driver.pre=vfio-pci`, no `vfio-pci ids=`, no boot-time rebind -- all
of that fought the NVIDIA driver for the card. Passthrough domains now
bind vfio-pci per VM, through libvirt's managed hostdev entries
(`managed='yes'`), which detach the card from the host driver on start
and give it back on stop.

On a host that ran an earlier image, the driver binding may also have
been forced by locally-added kernel arguments; the image's own
`rd.driver.pre=vfio-pci` goes away with this change, but anything added
by hand stays. Remove them once, then reboot:

```sh
sudo rpm-ostree kargs \
    --delete=rd.driver.pre=vfio-pci \
    --delete=vfio_pci.ids=10de:1e84,10de:10f8,10de:1ad8,10de:1ad9
```

While virtio-nvgpu guests are running the card is unavailable to
passthrough domains (and the other way around): stop the sharing guests
before starting a passthrough domain. `host/switch-gpu-win11.sh` from the
setup notes, or `virsh nodedev-detach`/`nodedev-reattach`, covers the
cases libvirt's automatic detach cannot.
