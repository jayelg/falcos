# Distrobox

Distrobox creates containers that integrate with the host user, home
directory, desktop and devices.

## Build

Installs Fedora's `distrobox` package. Podman supplies the default container
runtime through the `virtualization/podman` module in the image.

## Runtime

Create a development container with `distrobox create`, then enter it with
`distrobox enter`.
