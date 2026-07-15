[root](../../README.md) / [.github](../README.md) / **workflows**

The GitHub Actions pipelines.

### [Build Container Image](build.yml)

Builds both flavor images (falcos-desktop and falcos-laptop), then pushes and cosign signs them to ghcr.io. Runs on pushes to main and on a daily schedule. Pull requests build the laptop flavour only for build testing and does not Push.

### [Build Disk Images](build-disk.yml)

Turns the built image into installable disk images (qcow2 and Anaconda ISO) via bootc-image-builder, using the configs in [Disk Config](../../disk_config).

### [Kernel Freshness](kernel-freshness.yml)

Watches the CachyOS kernel COPR against upstream stable releases and CISA's KEV catalog (logic and thresholds in [kernel_freshness.py](../scripts/kernel_freshness.py)). Escalates from a tracking issue to a pre-validated PR flipping the image to the stock Fedora kernel, and opens the restore PR when the COPR catches up. Also validates the stock-kernel build path monthly so the fallback can't rot.

### [Lint and Test](lint.yml)

PR/push checks: shellcheck over the build and runtime scripts, actionlint over the workflows, and the [kernel_freshness.py unit tests](../scripts/test_kernel_freshness.py).

### [Bitwarden CLI Checksum](bw-checksum.yml)

Bitwarden publishes no official checksum for the CLI zip, so `BW_SHA256` is pinned in the repo. On PRs that bump `BW_VERSION` (Renovate), this recomputes the checksum, pushes the fix to the PR branch and dispatches validation builds.

### [Flyline Checksum](flyline-checksum.yml)

HalFrgrd/flyline publishes an official checksum per release asset, so `FLYLINE_SHA256` is pinned in the repo. On PRs that bump `FLYLINE_VERSION` (Renovate), this recomputes the checksum, pushes the fix to the PR branch and dispatches validation builds. Same pattern as [Bitwarden CLI Checksum](#bitwarden-cli-checksum) above.

### [Clean up Registry](cleanup-registry.yml)

Daily prune of old ghcr.io package versions: keeps the newest tagged builds per flavor plus their cosign signatures, and drops stale build-cache manifests.

## Notes / Todo
