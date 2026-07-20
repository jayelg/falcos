# vfio-passthrough

VFIO GPU-passthrough host setup. Desktop flavor only (gated by the
`[desktop]` section in [COMPONENTS.list](../../../../COMPONENTS.list)).
Pure-file component; pairs with the [looking-glass](../looking-glass) kvmfr
module. The passthrough device IDs are hardcoded in `modprobe.d/vfio.conf`.

## Files

- `kargs.d/00-vfio.toml` -- `iommu=pt`, `rd.driver.pre=vfio-pci`
- `modprobe.d/vfio.conf` -- binds the GPU's PCI IDs to vfio-pci, blacklists nouveau
- `dracut.conf.d/99-vfio.conf` -- pulls the vfio drivers into the initramfs
- `vfio-rebind-gpu-usb.service` + `45-falcos-vfio.preset` -- rebinds the GPU's USB controller to vfio-pci at boot
