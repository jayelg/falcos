[root](../../../README.md) / [build-phases](../../build-phases/README.md) / [modules](../README.md) / **_template**

# _template

A copy-me reference demonstrating **every** capability the build architecture
supports. The `module-name/` subdirectory *is* the module (copy it); this
top-level README is the how-to. Nothing here is listed in
[modules.kdl](../../../modules.kdl), so it never builds. The `_` prefix
just keeps it sorted to the top of the modules directory.

## Quick start

1. Copy the inner module directory to its destination. The path relative
   to `modules/` is the entry you'll add to modules.kdl:
   ```
   cp -r modules/_template/module-name modules/<group-or-name>/<name>
   ```
2. Delete the pieces you don't need — everything except a reason to exist is
   optional. A module can be as small as a single `files/` overlay, or just
   a `module.sh`.
3. Fill in `README.md` (every module has one), rename
   `45-falcos-template.preset` → `45-falcos-<name>.preset`, rename
   `Containerfile.inc.example` → `Containerfile.inc` only if you need it, and
   drop the `.example` config/libexec.
4. Add the module path (e.g. `core/my-module`) to `modules.kdl`. Position
   decides the RUN layer's place only where the declared graph doesn't; see
   **Ordering & flavors**.
5. `just generate` to confirm it resolves and splices in.

## Anatomy — what each file in `module-name/` does (all optional)

Run order within a module: `repo` → `versions.sh` → `module.sh` →
`selinux/*.te` → `files/` overlay → collected files. `finalize.sh`
runs much later, in the finalize layer.

| File | Purpose |
|---|---|
| `module.kdl` | **Required.** The manifest: description, base families, capabilities, contract files and options. See [SCHEMA.md](../SCHEMA.md). |
| `module.sh` | Install logic. Sourced under `set -euo pipefail` with `$MODDIR` set, pins in scope, and `$OPT_*` for every option declared in `module.kdl`. Omit for a pure-file module. |
| `versions.sh` | Renovate-tracked pins + SHA256s. `# renovate:` comment must sit directly above its version line. |
| `repo` | Third-party repo setup, made idempotent by `REPO_ID`; use `add_disabled_repo`. |
| `selinux/*.te` | Local SELinux policy modules, each auto-compiled + installed (priority 200). Declarative — no code in module.sh. |
| `files/` | Overlay copied verbatim into the image root. Ship a `usr/lib/systemd/*-preset/45-falcos-<name>.preset` here to enable/disable units. Shipping a path another module also ships is a lint failure unless the later one declares `overrides`. |
| `finalize.sh` | Run-once logic needing the real `systemctl` or the finished image. Sourced by 99-finalize.sh, flavor-gated, in build order. |
| `justfile.inc` | goojust recipes. Picked up because `core/goojust` declares it collects this filename; the destination lives there, not here. |
| `Containerfile.inc` | Verbatim Containerfile lines added above the generated block — only for what the declared fields cannot express, such as an `ARG` with a default or a second layer. Build secrets and args are declared in `module.kdl` instead. |
| `README.md` | Every module has one; the copy here is a fill-in skeleton. |

## Ordering & flavors (in modules.kdl)

- Build order comes from the graph: declare `requires "<capability>"` and
  the module builds after whatever provides it, wherever the two lines sit.
  Never order a dependency by hand.
- Where the graph says nothing, position in the list decides. Put heavy,
  rarely-changing modules early (better layer caching) and frequently-bumped
  ones late.
- A module nested in a `flavor "desktop" { }` block is gated to that flavor
  (the generator sets `FLAVOR_GATE`, and both `run-module.sh` and the
  `finalize.sh` loop skip it on other flavors). Gated modules always sort
  below the ungated ones, which is where the cache forks. Valid flavors are
  declared in the `flavors` block in `modules.kdl`.

## Key rules & gotchas

- **`systemctl` is stubbed during the build.** You cannot enable services in
  `module.sh` — ship a `45-falcos-<name>.preset` in `files/`, or do it in
  `finalize.sh` (which runs after systemctl is restored).
- **SELinux:** just drop a `selinux/<name>.te` — run-module.sh compiles and
  installs it. Author rules from real denials with `ausearch -m avc |
  audit2allow`. Only a policy you must *generate* at build time needs the
  imperative helper (write to `/tmp`; the module dir is a read-only mount).
- **shellcheck runs in CI** on every `*.sh` and on `files/{libexec,system-generators}`
  scripts. Sourcing a lib helper in `module.sh` also stops shellcheck from
  flagging your pin vars (SC2154); pin/override files use `# shellcheck
  disable=SC2034`.
- **The modules.kdl entry IS the path** relative to `modules/`. E.g.
  `core/my-module` for `modules/core/my-module/`. No uniqueness
  constraint across groups — `core/tools` and `de/tools` are distinct.

## Helpers available (`source /ctx/lib/<file>` in module.sh / finalize.sh)

`module.sh` shows a live, commented call for each — signatures here.

**fetch-helpers.sh** — install pinned release assets; every download is
SHA256-verified against the pin in `versions.sh`:
- `fetch_install_bin <url> <sha256> <name> [path-in-archive]` — single binary → `/usr/bin/<name>`
- `fetch_install_rpm <url> <sha256>` — download, verify, dnf-install an RPM
- `fetch_extract <url> <sha256> <dir> [extractor args…]` — verify + extract (extension picks the extractor; extra args pass through)
- `fetch_verified <url> <sha256> <dest>` — download + verify only, you handle the rest

**wrap-helpers.sh**
- `wrap_no_hardened_malloc <binary>` — wrap a GUI/Electron binary to drop the system-wide hardened_malloc `LD_PRELOAD` it crashes under

**repo-helpers.sh** (source in the `repo` file)
- `add_disabled_repo <repofile-url>` — install a `.repo` left disabled; uses `$REPO_ID` as the repo to disable

**selinux-helpers.sh** — usually not called directly; prefer dropping a
`selinux/*.te` (auto-installed). Use the helper only for a build-time-generated policy:
- `install_selinux_module <te>` — compile + install a `.te` (write it to `/tmp` first; the helper removes the source)

**dkms-helpers.sh** — out-of-tree kernel modules (MOK-signed when a key is mounted); the module also declares `requires "kernel-devel"`, `arg "KERNEL"` and `secret "mok_privkey"` in its manifest:
- `kernel_devel_install [extra-deps…]` / `kernel_devel_remove [extra-deps…]`
- `dkms_conf_version <src-dir>` — read `PACKAGE_VERSION` from a `dkms.conf`
- `dkms_build_module <name> <version> <src-dir>`

**kernel-helpers.sh / sign-helpers.sh** — kernel variant resolution and Secure
Boot signing; used by `kernel/cachyos-kernel`, rarely needed elsewhere.
