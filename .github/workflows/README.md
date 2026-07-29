[root](../../README.md) / **workflows**

The GitHub Actions pipelines.

### [Build Container Image](build.yml)

Builds one image per target (falcos for the ungated set, falcos-desktop and falcos-laptop for the flavors), rechunks them, then pushes and cosign signs them to ghcr.io. Runs on pushes to main and on a daily schedule. Pull requests build only the flavor marked `pr-build` in `modules.kdl`, for build testing, and do not push.

Lint runs first and gates the build: [lint.sh](../../scripts/lint.sh) (shellcheck over every Bash script in the repo, including the module scripts, a generator dry run over `modules.kdl`, and a render of the installer config), actionlint over the workflows, and the kernel freshness unit tests. `just lint` runs the same script, so the local check and the gate cannot drift. A lint failure stops the matrix before any image is built.

The build itself is [build.sh](../../scripts/build.sh), which `just build` also runs. It owns the Containerfile generation, the build args, the registry cache refs and the Secure Boot secret, so a local build and a CI build of the same commit differ only in the backend that reaches BuildKit. The workflow keeps the policy around it: which events may read and write the cache, and which produce a publishable artifact.

Rechunking (`rpm-ostree compose build-chunked-oci`, the Bazzite/ublue pattern) repacks the built image into content-stable layers chunked by package group, so `bootc upgrade` downloads only the packages that actually changed rather than every layer above the first drifted `RUN`. The buildx registry cache is unaffected — it caches the build stages, while the chunked repack is what gets published.

Each published digest also carries a syft SPDX SBOM as a cosign in-toto attestation, verifiable with `cosign verify-attestation --key cosign.pub --type spdxjson --insecure-ignore-tlog=true <image>` (the flag skips the Rekor transparency-log check, which this key-based flow doesn't use — trust comes from the key).

The attested document is the package inventory. The full file-level SBOM, which also records which package owns each path, is 148MB and cannot be attested: cosign refuses an attestation layer over 128MiB, and raising `COSIGN_MAX_ATTACHMENT_SIZE` would only move the problem to every consumer. It is uploaded as the `sbom-falcos-<flavor>` build artifact instead.

### [Build Disk Images](build-disk.yml)

Turns the built image into installable disk images (qcow2 and Anaconda ISO) via bootc-image-builder, using the configs in [Disk Config](../../disk_config). Which flavor it builds, and which image the ISO switches the installed system to, both come from the installer flavor declared in [Flavors](../../scripts/flavors.sh); the kickstart reference is rendered from it rather than written down.

> **A new target's first publish creates a GHCR package, and GitHub makes new packages private.** CI will not notice, because `GITHUB_TOKEN` carries `packages: read` for the repository's own packages, so the ISO build keeps succeeding while the reference it bakes in is unpullable by anyone else. Flip the package to public after its first push.

### [Kernel Freshness](kernel-freshness.yml)

Watches the CachyOS kernel COPR against upstream stable releases and CISA's KEV catalog (logic and thresholds in [kernel_freshness.py](../../modules/kernel/cachyos-kernel/kernel_freshness.py)). Escalates from a tracking issue to a pre-validated PR flipping the image to the stock Fedora kernel, and opens the restore PR when the COPR catches up. Also validates the stock-kernel build path monthly so the fallback can't rot.

### [Checksums](checksums.yml)

Release assets pinned with a repo-tracked SHA256 (Bitwarden CLI, flyline, the Affinity Wine/DXVK/vkd3d-proton tarballs, the falcos-bootc-updates RPM) are listed in a table inside the workflow. On PRs that bump their version pins (Renovate), this recomputes every stale checksum in one pass, pushes a single fixup commit to the PR branch and dispatches validation builds. One workflow covers every asset so concurrent fixup pushes to the same branch cannot race.

### [Clean up Registry](cleanup-registry.yml)

Daily prune of old ghcr.io package versions: keeps the newest tagged builds per flavor plus their cosign signatures and SBOM attestations, and drops stale build-cache manifests.

## Notes / Todo
