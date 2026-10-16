# nvidia-container-toolkit

The container toolkit (`nvidia-ctk`) and the **CDI spec** that makes the
host's NVIDIA driver usable by containers — the piece that turns
`podman run --device nvidia.com/gpu=all` (or a quadlet's `AddDevice=nvidia.com/gpu=all`)
into a working GPU container.

## What this module installs

- **`nvidia-container-toolkit`**, from NVIDIA's libnvidia-container repo
  (added disabled, opted into per install). Ships `nvidia-ctk`.
- **`nvidia-cdi.service`**, a boot-time oneshot that runs
  `nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml` and is enabled by
  the module's preset.

## Why the CDI spec is generated at boot, not build time

The generated spec names the driver's **exact library filenames**
(`libcuda.so.615.71.09`, `libEGL_nvidia.so.615.71.09`, …). A spec baked
into the image therefore pins the *build host's* driver version and goes
stale the moment the runtime image carries a different one — every GPU
container then fails with:

```
Error: crun: cannot stat `/usr/lib64/libEGL_nvidia.so.<old-version>`:
No such file or directory
```

On a bootc/ostree system the driver lives in the immutable `/usr` that
boots, so a driver update is a new deployment and a reboot. Regenerating
in `nvidia-cdi.service` at boot means the spec is always a pure function
of the driver the running system actually has, and a driver update can
never leave a stale spec behind.

## Relationship with the driver module

**Requires** the `nvidia-driver` capability (`hardware/nvidia` provides
it): `nvidia-ctk` reads the driver libraries and `/sys` to describe the
card. The service also orders after `systemd-modules-load.service`, which
the driver module's `modules-load.d/nvidia.conf` uses to bring up
`nvidia_drm` / `nvidia_uvm` — `nvidia-ctk` needs the character devices
present.

This module is flavor-gated to `desktop` alongside `hardware/nvidia`,
since a container GPU consumer cannot exist without the host driver.
