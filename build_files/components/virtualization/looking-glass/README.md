[root](../../../../README.md) / [build_files](../../../README.md) / [components](../../README.md) / **looking-glass**

Builds the Looking Glass `kvmfr` DKMS module, the shared-memory transport between the host and a GPU-passthrough VM. Desktop flavor only (gated via `COMPONENT_FLAVORS` in [Containerfile.part](Containerfile.part)); the matching VFIO kargs, modprobe config and rebind service ship in the `vfio-passthrough` component.

- `versions.sh` pins the upstream release tag; the module version is read from upstream's `dkms.conf`.
- `files/` ships the udev rule granting the `kvm` group access to `/dev/kvmfr0` (the user must be in the `kvm` group).
- Signed with the MOK key when the build supplies one, like the kernel and xone modules.
