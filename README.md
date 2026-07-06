# falcos

A custom [bootc](https://github.com/bootc-dev/bootc) image built on Fedora, with KDE Plasma installed directly from Fedora's own comps groups rather than inherited from a downstream desktop spin.

Two flavors are built from the same `Containerfile`, selected via the `FLAVOR` build arg (`desktop`, `laptop`).

## Repository layout

The build is split into many `Containerfile` `RUN` layers, each scoped by its own bind mount to only the scripts (and version-pin file, if any) it needs — so a change to one group, whether a script edit or a Renovate version bump, only busts that group's own build cache and only forces a re-download of that group's layer on `bootc upgrade`, not a whole phase. `phase-setup` and every `common/core` group are also deliberately flavor-agnostic (no `FLAVOR` reference anywhere in them), so both `desktop` and `laptop` builds produce byte-identical layers there and share one build cache instead of each flavor redundantly rebuilding the same work. `files/common` itself is copied wholesale only in `phase-finalize.sh` (the last layer) rather than upfront — everything in it is consumed at boot/runtime, not read during any script's own execution, so editing any file under it never busts the expensive layers above; the two exceptions genuinely read mid-build (`sb_cert.der`, `99-hardening`) get their own narrow mounts in whichever group needs them:

1. **`build_files/phase-setup.sh`** — masks `systemd-remount-fs.service`, applies the `/opt` and `systemctl`-stub workarounds ostree/bootc package installs need
2. **`build_files/phase-core.sh`**, run once per themed group of `build_files/common/core/` scripts, each its own layer:
   - repos (`000-repos.sh`)
   - KDE desktop + theming (`010-kde-desktop.sh`, `020-kde-theming.sh`) — uses `versions-core-theming.sh`
   - CLI + dev tools (`030-cli-tools.sh`, `040-dev-tools.sh`)
   - bootloader, CachyOS kernel, hardware, xone DKMS driver (`050`–`080`) — uses `versions-core-kernel.sh` + MOK secret + `sb_cert.der`
   - multimedia, networking, virtualization (`090`–`110`)
   - security, hardening, SELinux (`120`–`140`) — uses `99-hardening`
   - COPR extras, greenboot (`150`, `160`)
3. **`build_files/phase-frequent.sh`**, run once per themed group of `build_files/common/frequent/` scripts:
   - pinned CLI tools + codium (`000-pinned-tools.sh`) — uses `versions-frequent-tools.sh`
   - VPN clients, network-audio, the Trivalent browser (`010`–`030`) — uses `versions-frequent-network.sh`
4. **`build_files/phase-flavor.sh`** — copies flavor-specific `files/${FLAVOR}`, uses `versions-frequent-desktop.sh`, runs the active flavor script (`desktop.sh`/`laptop.sh`); inherently flavor-divergent, so kept separate from the groups above that are common to both flavors
5. **`build_files/phase-finalize.sh`** — copies `files/common`, restores `systemctl`, regenerates the initramfs against the final module set, patches the container signing policy, applies `enable-services.sh`

Other pieces:
- **`build_files/versions-core-*.sh` / `versions-frequent-*.sh`** — every pinned third-party version/commit, one file per themed group above, annotated for Renovate (`.github/renovate.json5`'s `customManagers`) so bumps arrive as PRs instead of needing to be found by hand
- **`build_files/lib/sign-helpers.sh`** — shared Secure Boot (MOK) module/kernel signing functions, sourced by the kernel, DKMS-module, and flavor scripts (never auto-run — not matched by any phase script's glob)
- **`build_files/enable-services.sh`** — all `systemctl enable` calls, grouped by which `common/` script installed the corresponding package (must run after the `systemctl` stub is torn down in `phase-finalize.sh`, so these can't live inline in the topic scripts)
- **`build_files/files/`** — file trees copied into the image root (`common/`, `desktop/`, `laptop/`)
- **`disk_config/`** — `bootc-image-builder` configs for VM/ISO builds

## Building and testing locally

Requires [`just`](https://just.systems/man/en/introduction.html) and `podman`.

```bash
# Build a container image locally
just build $target_image $tag

# Build a bootable QCOW2 VM image from an already-built container image
just build-qcow2 $target_image $tag

# Run that VM (opens a noVNC console in your browser)
just run-vm-qcow2 $target_image $tag

# Rebuild the container image and the VM image in one step
just rebuild-qcow2 $target_image $tag
```

Building/running the VM requires `sudo`, since `bootc-image-builder` needs privileged access to build disk images.

Other useful recipes: `just lint` (shellcheck all scripts), `just format` (shfmt), `just check`/`just fix` (Justfile syntax), `just clean` (remove build artifacts).

## Secure Boot (kernel/module signing)

The CachyOS kernel and the xone/kvmfr DKMS modules are built in-image and need to be signed with a MOK (Machine Owner Key) to load under Secure Boot. Without a signing key, the build still succeeds — it just produces an unsigned kernel/modules, which Secure Boot will refuse to load.

**One-time setup:**

```bash
just generate-mok-key
export MOK_KEY_PATH=~/.local/share/falcos/MOK.priv   # add to your shell profile
cp ~/.local/share/falcos/sb_cert.der build_files/files/common/usr/share/falcos/sb_cert.der
```

Commit `sb_cert.der` (it's a public cert, safe to commit — like `cosign.pub`). Keep `MOK.priv` out of git (already in `.gitignore`); add its contents as the `MOK_PRIVATE_KEY` GitHub Actions secret for CI builds.

**After deploying a signed image**, on the target machine, once:

```bash
sudo mokutil --import /usr/share/falcos/sb_cert.der
```

Enter an enrollment password when prompted, then reboot. The firmware's MokManager blue screen appears automatically — select **Enroll MOK** → **Continue** → confirm the fingerprint → enter the password → **Reboot**. After this one-time enrollment, Secure Boot trusts everything this repo signs, on every future build/update, with no further manual steps.

## Dual-boot (Windows entries in GRUB)

`just regenerate-grub` (from the skel justfile, so available as a plain `just` command on any deployed machine) regenerates `grub.cfg` with os-prober so other installed OSes show up in the boot menu. It's on-demand only, not run automatically — and **currently always fails** (`grub2-probe: failed to get canonical path of 'composefs'`), a confirmed, still-open upstream bug in the ostree/bootc ecosystem ([ostreedev/ostree#3198](https://github.com/ostreedev/ostree/issues/3198)) that grub2-probe can't resolve composefs's root mount. Bazzite hits the identical failure in its own `ujust regenerate-grub` ([ublue-os/bazzite#2519](https://github.com/ublue-os/bazzite/issues/2519)) — there's no known fix yet anywhere in the ecosystem. The command is kept (rather than removed) so it's ready to work once that's fixed upstream.

## CI/CD

- **`.github/workflows/build.yml`** builds and pushes both flavors to `ghcr.io` on push to `main`, daily on a schedule, and on pull requests. Images are signed with cosign (`SIGNING_SECRET`), and the kernel/DKMS modules are signed with the MOK key (`MOK_PRIVATE_KEY`) — both secrets are only used on pushes to the default branch, never on PRs/forks.
- **`.github/workflows/build-disk.yml`** builds QCOW2/ISO disk images on demand.
