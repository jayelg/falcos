# wolf

Wolf, a streaming server for Moonlight clients, running Steam in its
Gamepad UI (the fullscreen Big Picture) headless: the container presents a
virtual display and reads input over the network, so the host's own display
and input devices are never bound.

## What this module installs

- **`wolf.container`** at `/etc/containers/systemd/` — a rootful quadlet,
  the shape upstream documents.
- **`85-wolf.rules`** (`/etc/udev/rules.d/`), pinned by commit and hash:
  grants access to `/dev/uinput` and `/dev/uhid`, and parks Wolf's virtual
  controllers on a phantom seat so a streamed pad does not also drive the
  host desktop (wolf#451).

Wolf and its per-app containers are pulled from
`ghcr.io/games-on-whales/wolf:stable` at runtime; no package is installed
into the image.

## Why the driver is mounted, not built into a volume

Upstream's manual Nvidia path builds a `gow/nvidia-driver` image from the
NVIDIA `.run` installer and populates a volume from it — a runtime image
build that has to be redone on every driver update. This image already
carries the driver, so `hardware/nvidia` collects the userspace into the
NVIDIA-installer layout at `/usr/lib64/nvidia-gow/` and this quadlet mounts
it read-only at `/usr/nvidia`, which is where the GOW images' `ld.so.conf`
looks. Same result, no runtime build, and the mounted tree is the immutable
driver the system booted.

## Why rootful

The `/dev/nvidia*` nodes, `/dev/uinput` and `/dev/uhid` (root-owned, seat
tagged) and the podman socket Wolf uses to launch app containers are all
system resources. Upstream's guidance is a rootful service and the device
and udev story is built for it; a rootless install cannot open `/dev/uhid`.

## Why not the container toolkit

Wolf's own docs warn against the Nvidia container toolkit for Steam: EGL
init fails and the compositor falls back to software rendering
(wolf#152). The driver-volume path is the one upstream says works for
gaming.

**Requires:** the `nvidia-driver` capability (`hardware/nvidia` provides
it). Flavor-gated to `desktop`.
