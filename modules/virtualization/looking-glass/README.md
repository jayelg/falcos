[root](../../../../README.md) / [build-phases](../../../../build-phases/README.md) / [modules](../../README.md) / **looking-glass**

Builds the Looking Glass `kvmfr` DKMS module, the shared-memory transport between the host and a GPU-passthrough VM. Desktop flavor only (gated via `FLAVOR_GATE` in [Containerfile.inc](Containerfile.inc)); the matching VFIO kargs, modprobe config and rebind service ship in the `vfio-passthrough` module.

- `versions.sh` pins the upstream release tag; the module version is read from upstream's `dkms.conf`.
- `files/` ships the udev rule granting the `kvm` group access to `/dev/kvmfr0` (the user must be in the `kvm` group).
- Signed with the MOK key when the build supplies one, like the kernel and xone modules.
