[root](../../README.md) / **workflows**

The GitHub Actions pipelines.

Which of them run is declared in the [`workflows` block in image.kdl](../../modules/SCHEMA.md#workflows) and reconciled by [Reconcile workflow toggles](reconcile-workflows.yml). A workflow not named there runs, so nothing below is off today.

### [Build Container Image](build.yml)

Builds one image per target, a target being an image and a flavor of it (`falcos/none` publishes as falcos, `falcos/desktop` as falcos-desktop), rechunks them, then pushes and cosign signs them to ghcr.io. Every declared image contributes its own targets to the matrix. Runs on pushes to main and on a daily schedule. Pull requests build one target only, the image marked `pr-image` in `repo.kdl` at the flavor marked `pr-build`, for build testing, and do not push.

Lint runs first and gates the build: [lint.sh](../../scripts/lint.sh) (shellcheck over every Bash script in the repo, including the module scripts, a regeneration of the Containerfile checked against the committed one, and a render of the installer config), actionlint over the workflows, and the kernel freshness unit tests. `just lint` runs the same script, so the local check and the gate cannot drift. A lint failure stops the matrix before any image is built.

The build itself is [build.sh](../../scripts/build.sh), which `just build` also runs. It owns the Containerfile generation, the build args, the registry cache refs and the Secure Boot secret, so a local build and a CI build of the same commit differ only in the backend that reaches BuildKit. The workflow keeps the policy around it: which events may read and write the cache, and which produce a publishable artifact.

Each build job writes the resolved module set for its target to the run summary, taken from the same parser that generates the Containerfile, and uploads the generated Containerfile as the `containerfile-falcos-<flavor>` artifact.

Rechunking (`rpm-ostree compose build-chunked-oci`, the Bazzite/ublue pattern) repacks the built image into content-stable layers chunked by package group, so `bootc upgrade` downloads only the packages that actually changed rather than every layer above the first drifted `RUN`. The buildx registry cache is unaffected — it caches the build stages, while the chunked repack is what gets published.

Each published digest also carries a syft SPDX SBOM as a cosign in-toto attestation, verifiable with `cosign verify-attestation --key modules/core/signature-policy/files/etc/pki/containers/cosign.pub --type spdxjson --insecure-ignore-tlog=true <image>` (the flag skips the Rekor transparency-log check, which this key-based flow doesn't use — trust comes from the key). The key lives in the module that owns the signing policy rather than at the repo root; on an installed machine the same file is at `/etc/pki/containers/cosign.pub`.

The attested document is the package inventory. The full file-level SBOM, which also records which package owns each path, is 148MB and cannot be attested: cosign refuses an attestation layer over 128MiB, and raising `COSIGN_MAX_ATTACHMENT_SIZE` would only move the problem to every consumer. It is uploaded as the `sbom-falcos-<flavor>` build artifact instead.

### [Build Disk Images](build-disk.yml)

Turns a published image into installable disk images (qcow2 and Anaconda ISO) via bootc-image-builder, using the configs in [Disk Config](../../disk_config). Both the payload and the image the ISO switches the installed system to are the ungated `falcos` build, by rule rather than by a configured value: kargs under `/usr/lib/bootc/kargs.d/` are static, so a payload for an uninspected machine has to be the set that gates on no hardware. The kickstart reference is rendered from that rather than written down.

> **This workflow builds from a *published* image, so one has to exist.** An image package is created by a push to the default branch, and GitHub makes a new package private on first publish — and ghcr answers an unauthorised request with 403 rather than 404, so "never pushed" and "private" look identical. Both fail the same way. The workflow checks for this up front and says which it is, rather than letting the failure surface as a bare 403 from the pull. Flip a new package to public after its first push.

### [VM Boot Smoke Test](smoke-test.yml)

Weekly proof that the published image boots, which nothing else in the pipeline establishes: the pre-publish validation in [validate-image.sh](../../lib/validate-image.sh) reads a filesystem, and a filesystem that passes every assertion can still fail to reach a login. Pulls the published image, turns it into a qcow2 with bootc-image-builder using the committed [Disk Config](../../disk_config), injects a throwaway SSH key with `virt-customize`, boots it headless under qemu and asserts over SSH that `bootc status` parses, that `systemctl is-system-running` reports `running`, and that no unit has failed.

`/dev/kvm` is the first step, ahead of the pull and the disk build, because the boot uses `-enable-kvm` and `-cpu host` and a runner without KVM should cost a second rather than the whole job. The serial console is written to a file and dumped when the job fails, since qemu runs in the background and a VM that never reaches sshd leaves nothing else to read.

Scheduled after the daily build so the image under test is the one users are getting, and it runs on `workflow_dispatch` too. Not a pre-publish gate yet: it is promoted to one once it has been stable for long enough to trust a red run.

### [Kernel Freshness](kernel-freshness.yml)

Watches the CachyOS kernel COPR against upstream stable releases and CISA's KEV catalog (logic and thresholds in [kernel_freshness.py](../../modules/kernel/cachyos-kernel/kernel_freshness.py)). Escalates from a tracking issue to a pre-validated PR flipping the image to the stock Fedora kernel, and opens the restore PR when the COPR catches up. Also validates the stock-kernel build path monthly so the fallback can't rot.

### [Base Image Signature Probe](base-sig-probe.yml)

Daily watch for the day `quay.io/fedora/fedora-bootc` starts publishing cosign signatures, which is the precondition for gating the `FROM` pull with a `policy.json` and a `registries.d` entry on the builder. Until then the build pulls its base unverified, and the point of a probe is that nobody has to keep checking by hand. Opens one tracking issue when the answer changes, and does nothing on every other run.

The base image reference is read out of the [`base` node in image.kdl](../../image.kdl) via `manifest base-image` rather than written down here, so the probe cannot drift from what the build actually pulls.

It asks about existence, not trust: `cosign triangulate` names where a signature would live and `cosign download signature` says whether one is there. Verifying properly would need a key or a certificate identity, and fedora publishes neither for this image, which is the very fact being waited on. Nothing is verified against the result, an issue is opened for a human to act on. This finds a signature published the way `cosign sign` publishes one by default, as a `.sig` tag beside the image; a referrers-only signature would go unnoticed, which is the trade for not depending on the referrers API.

### [Checksums](checksums.yml)

The mechanical follow-up to a pin bump. Renovate can move an asset's `version` or an out-of-tree module's `ref` but cannot recompute the `sha256` either one is verified against, and both are baked into the generated Containerfiles, which lint checks for drift. On a PR touching a module manifest or the module list this recomputes every stale checksum in one pass, regenerates the Containerfile, pushes a single fixup commit to the PR branch and dispatches a validation build. One workflow covers every pin so concurrent fixup pushes to the same branch cannot race.

It carries no list of assets: `manifest.sh assets` and `manifest.sh remotes` report every pin with its resolved URL, which is the same resolution the build uses, so what this hashes and what the build fetches cannot disagree. Only the manifests the PR actually touched are checked, and a pin whose `sha256` is `from="manual"` is skipped — for an asset whose filename does not follow from its version, recomputing would hash whatever the old URL still serves. Module pins are recomputed first, since fetching an out-of-tree module verifies its archive against the hash in the list.

### [Clean up Registry](cleanup-registry.yml)

Daily prune of old ghcr.io package versions: keeps the newest tagged builds per target plus their cosign signatures and SBOM attestations, and drops stale build-cache manifests.

### [Reconcile workflow toggles](reconcile-workflows.yml)

Applies the [`workflows` block in image.kdl](../../modules/SCHEMA.md#workflows) to what GitHub actually has enabled, on every push to main touching that file or this directory. Reads the declaration through `manifest workflows`, which answers with every file here and the state declared for it, so this workflow carries no list of its own and cannot drift from the block.

Through `PUT /actions/workflows/{id}/{enable,disable}`, never by editing the files here. `GITHUB_TOKEN` cannot push a change to a path under `.github/workflows/`, so a reconciler that rewrote them would need a PAT or a GitHub App, and a fork of this repository would have to provision a secret before it worked at all. Nothing else in the repo needs elevated credentials, and the API does the same job with `actions: write`, leaving no commit and nothing for the drift check to notice.

A workflow that has never been on the default branch is not registered with Actions and is skipped rather than treated as disabled. `disabled_inactivity`, which is GitHub switching a scheduled workflow off after 60 days of repository quiet, reconciles back to active like any other difference.

It never disables itself: that would leave the declaration with nothing to act on it and no way back in from the file. The check resolves this workflow's own filename from `GITHUB_WORKFLOW_REF` at run time, so no path to it is written down. A fork that wants none of this deletes the file.

## Notes / Todo
