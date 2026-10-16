# wolf

Wolf, a streaming server for Moonlight clients, running Steam in its
Gamepad UI (the fullscreen Big Picture) headless: the container presents a
virtual display and reads input over the network, so the host's own display
and input devices are never bound.

## What this module installs

A single quadlet, `wolf.container`, at
`/etc/containers/systemd/users/` — the rootless quadlet search path that
applies to **every** user's session. One file, so any user who logs in gets
their own Wolf server, on their own runtime socket and their own state, with
nothing written into a home directory at image build time.

The quadlet is a pure-file deliverable: Wolf and its per-app containers are
pulled from `ghcr.io/games-on-whales/wolf:stable` at runtime, so no package
is installed into the image.

## How it gets the GPU

`AddDevice=nvidia.com/gpu=all` consumes the CDI spec that
`hardware/nvidia-container-toolkit` writes to `/etc/cdi/nvidia.yaml` at
boot. That is why this module **requires** the `nvidia-driver` capability: a
CDI spec is a function of the loaded driver, and without one the device
simply is not there.

## Headless by construction

- No `/dev/input` is bound; Moonlight clients send input over the network
  and Wolf feeds it to a virtual gamepad (`uinput`/`uhid`).
- No host display is bound; Wolf runs its own virtual compositor and the
  DRM render node is used only for encoding.
- `/dev` and `/run/udev` are shared so hotplug and Wolf's own virtual
  devices are visible to it.

## Per-user isolation

State (`%h/.local/share/wolf`), sockets (`%t/wolf`) and the podman socket
(`%t/podman/podman.sock`) are all per-user systemd specifiers, so several
users on one machine never collide. The app UID/GID come from the session
(`%U`/`%G`) rather than being hardcoded.

**Requires:** the `nvidia-driver` capability (`hardware/nvidia` provides
it). Flavor-gated to `desktop`, since it cannot work without the GPU stack.
