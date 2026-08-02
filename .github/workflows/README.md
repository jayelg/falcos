[root](../../README.md) / **workflows**

#### How to disable workflows

Workflows are enabled by default however they can be disabled in the worflow node of [repo.kdl](../../repo.kdl).
The [Reconcile workflow toggles](reconcile-workflows.yml) runs when changes are committed to [repo.kdl](../../repo.kdl) and disables workflows through the github API. 

### [Build Container Image](build.yml)

This workflow builds an image defined in an image file eg. [image.kdl](../../image.kdl).
The build script that runs is [build.sh](../../scripts/build.sh).

- Lint runs first and gates the build: [lint.sh](../../scripts/lint.sh)
- The parser generates the containerfiles for each image definition eg. [image.kdl](../../image.kdl): [gen-containerfile.sh](../../scripts/gen-containerfile.sh).
- The compute matrix stage computes what image flavors need to be built
- Rechunk to reduce the size of update downloads: (`rpm-ostree compose build-chunked-oci`)
- creates a syft SPDX SBOM
- Cosign signs the images to ghcr.io.
- Uploads the generated containerfile and the full file level SBOM as run artifacts

This workflow runs on a daily schedule and on merges to main.

Pull requests build 1 target only which can be selected in `repo.kdl`.

To verify the SBOM attestation on a published image:

```bash
cosign verify-attestation --key modules/core/signature-policy/files/etc/pki/containers/cosign.pub --type spdxjson --insecure-ignore-tlog=true <image>
```

The same public key is on an installed system at `/etc/pki/containers/cosign.pub`.

### [Build Disk Images](build-disk.yml)

Turns a published image into installable disk images with bootc-image-builder, using the configs in [disk_config](../../disk_config).

- Builds a qcow2 disk image and an Anaconda installer ISO, downloadable from the run artifacts
- Both use the ungated image because flavor kargs are static and can't be made conditional on unknown hardware
- The ISO's kickstart reference is rendered by [render-iso-config.sh](../../scripts/render-iso-config.sh)

Run it manually with workflow dispatch. It also runs on pull requests touching the disk configs.

> The image has to already be published for this to work, so a newly added target needs a push to main first. Image packages are also private on first publish, which won't stop this workflow but will stop anyone installing the image with bootc switch, so ensure they are public after the first build.

### [VM Boot Smoke Test](smoke-test.yml)

Boots the published image in a VM to prove it starts. The pre-publish checks in [validate-image.sh](../../lib/validate-image.sh) only inspect the filesystem, which can pass on an image that never reaches a login.

- Pulls the published image and converts it to a qcow2 with bootc-image-builder
- Injects a throwaway SSH key with `virt-customize` and boots it headless under qemu
- Asserts over SSH that `bootc status` parses, that `systemctl is-system-running` reports `running` and that no unit has failed
- Dumps the serial console when the job fails

Runs weekly after the daily build, and on workflow dispatch. Needs a runner with `/dev/kvm`.

### [Kernel Freshness](kernel-freshness.yml)

Checks that a custom kernel isn't stale and temporarily falls back to the stock Fedora kernel if it is.

A kernel module opts in by shipping a `kernel_freshness.py` that knows how to check its own upstream.

| Result | Action |
| --- | --- |
| More than 7 days behind | Opens or updates a tracking issue |
| More than 14 days behind, EOL, or an unpatched KEV CVE | Also opens a PR setting `ARG KERNEL` to stock in the module's `Containerfile.inc` |
| Upstream catches up | Closes the issue, and opens a restore PR if the fallback was merged |

Runs daily. A monthly run also builds the stock kernel path so the fallback can't break unnoticed.

### [Base Image Signature Probe](base-sig-probe.yml)

Checks whether the base image publishes a cosign signature. A signed base can have its `FROM` pull gated with a `policy.json`, so the base layer is verified rather than trusted.

- Reads the base image from the [`base` node](../../image.kdl) with `manifest base-image`
- Asks whether a signature exists with `cosign triangulate` and `cosign download signature`, not whether one is valid
- Opens a tracking issue when one appears, and does nothing otherwise

Runs daily.

> Written for a base that is unsigned, which is the case for the default `quay.io/fedora/fedora-bootc`. It only alerts on a signature appearing, so a base that is already signed opens one issue on the first run. It also only checks the default image's base.

### [Checksums](checksums.yml)

This workflow recomputes the `sha256` for pinned assets for Renovate when it bumps an asset's `version` or an out-of-tree module's `ref`.

- Recomputes every stale checksum, regenerates the containerfiles and pushes one fixup commit to the PR branch
- Reads every pin from `manifest.sh assets` and `manifest.sh remotes`, so it hashes the same URL the build fetches
- Out-of-tree module pins are recomputed first, since fetching one of those verifies its archive against the hash
- A pin declared `sha256 from="manual"` is skipped
- Dispatches a validation build, as a fixup commit pushed with `GITHUB_TOKEN` doesn't trigger one

Runs on pull requests touching a `module.kdl` or a root `.kdl`.

### [Clean up Registry](cleanup-registry.yml)

Prunes old ghcr.io package versions.

- Keeps the newest 3 tagged builds per image, with their cosign signatures and SBOM attestations
- Drops stale build cache manifests
- Workflow dispatch takes a `dry-run` input that logs what would be deleted without deleting it

Runs daily, after the image build.

### [Reconcile workflow toggles](reconcile-workflows.yml)

Applies the `workflows` node in [repo.kdl](../../repo.kdl) to what GitHub has enabled, through the Actions API rather than by editing the files here.

- Reads the declared state with `manifest workflows`, so it holds no list of its own
- A workflow that has never been on the default branch isn't registered with Actions, and is skipped rather than treated as disabled
- A scheduled workflow GitHub switched off after 60 days of repository inactivity is switched back on
- It skips itself and so can't be disabled. Delete the file instead

Runs on pushes to main that touch [repo.kdl](../../repo.kdl) or this directory.

## Notes / Todo
