[root](../../README.md) / [.github](../README.md) / **workflows**

The GitHub Actions pipelines.

### [Build Container Image](build.yml)

Builds both flavor images (falcos-desktop and falcos-laptop), then pushes and cosign signs them to ghcr.io. Runs on pushes to main and on a daily schedule. Pull requests build the laptop flavour only for build testing and does not Push.

### [Build Disk Images](build-disk.yml)

Turns the built image into installable disk images (qcow2 and Anaconda ISO) via bootc-image-builder, using the configs in [Disk Config](../../disk_config).

## Notes / Todo
