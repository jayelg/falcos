[root](../../README.md) / **workflows**

The GitHub Actions pipelines.

### [Build Container Image](build.yml)

Builds both flavor images (falcos-desktop and falcos-laptop), rechunks them, then pushes and cosign signs them to ghcr.io. Runs on pushes to main and on a daily schedule. Pull requests build only the first flavor in `ARG FLAVORS`, for build testing, and do not push.

Lint runs first and gates the build: shellcheck over the build and runtime scripts, actionlint over the workflows, and the kernel freshness unit tests. A lint failure stops the matrix before any image is built.

Rechunking (`rpm-ostree compose build-chunked-oci`, the Bazzite/ublue pattern) repacks the built image into content-stable layers chunked by package group, so `bootc upgrade` downloads only the packages that actually changed rather than every layer above the first drifted `RUN`. The buildx registry cache is unaffected — it caches the build stages, while the chunked repack is what gets published.

Each published digest also carries a syft SPDX SBOM as a cosign in-toto attestation, verifiable with `cosign verify-attestation --key cosign.pub --type spdxjson --insecure-ignore-tlog=true <image>` (the flag skips the Rekor transparency-log check, which this key-based flow doesn't use — trust comes from the key).

### [Build Disk Images](build-disk.yml)

Turns the built image into installable disk images (qcow2 and Anaconda ISO) via bootc-image-builder, using the configs in [Disk Config](../../disk_config).

### [Kernel Freshness](kernel-freshness.yml)

Watches the CachyOS kernel COPR against upstream stable releases and CISA's KEV catalog (logic and thresholds in [kernel_freshness.py](../../components/kernel/cachyos-kernel/kernel_freshness.py)). Escalates from a tracking issue to a pre-validated PR flipping the image to the stock Fedora kernel, and opens the restore PR when the COPR catches up. Also validates the stock-kernel build path monthly so the fallback can't rot.

### [Checksums](checksums.yml)

Release assets pinned with a repo-tracked SHA256 (Bitwarden CLI, flyline, the Affinity Wine/DXVK/vkd3d-proton tarballs, the falcos-bootc-updates RPM) are listed in a table inside the workflow. On PRs that bump their version pins (Renovate), this recomputes every stale checksum in one pass, pushes a single fixup commit to the PR branch and dispatches validation builds. One workflow covers every asset so concurrent fixup pushes to the same branch cannot race.

### [Clean up Registry](cleanup-registry.yml)

Daily prune of old ghcr.io package versions: keeps the newest tagged builds per flavor plus their cosign signatures and SBOM attestations, and drops stale build-cache manifests.

## Notes / Todo
