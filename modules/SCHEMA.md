[root](../README.md) / [modules](README.md) / **manifest schema**

The declared interface between a module and everything outside it. Two
files, one parser ([tools/manifest](../tools/manifest), reached through
[scripts/manifest.sh](../scripts/manifest.sh)), both KDL 2.0.

- **[image.kdl](../image.kdl)** — the image author's file. Which
  modules are in the image, in what order, gated to which flavors, with
  which options set.
- **`modules/<path>/module.kdl`** — the module author's file, required
  for every module. What the module needs, what it offers, and what an
  image author may configure.

The split is ownership. A module never names a flavor and never decides
whether it is included; an image author never restates what a module
needs. Anything one of them must know about the other goes in a manifest,
because a shell script can only be read by running it.

## What is not declared

Mechanics stay presence driven. The runner checks for these and acts on
them; declaring them beside an existing file would be redundant and could
drift both ways.

| Path | Effect |
| --- | --- |
| `module.sh` | sourced as the install logic |
| `repo` | sourced once, idempotent via its `REPO_ID` |
| `selinux/*.te` | compiled and installed at priority 200 |
| `files/` | copied verbatim into the image |
| `finalize.sh` | sourced by the finalize phase, in resolved order |
| a file another module `collects` | handed to that module |

A manifest declares *facts*, not *file layout*.

## image.kdl

Four top-level nodes. `flavors` is optional; `image`, `base` and `modules`
are required.

```kdl
image "falcos" {
    name "Falcos"
    url "https://github.com/jayelg/falcos"
    issues-url "https://github.com/jayelg/falcos/issues"
    logo "brand/distributor-logo-symbolic.svg"
    watermark "brand/watermark.png"
}

base "quay.io/fedora/fedora-bootc:44" {
    family "fedora"
    provides "rechunking" "initramfs-generation" "mac-policy"
    provides-file "/usr/bin/bootc" "/usr/bin/systemctl" "/usr/bin/rpm-ostree"
}

flavors {
    // default marks the flavor `just build` and a bare scripts/build.sh
    // produce. A build-order convenience and nothing more: it makes no
    // claim about which image belongs on a machine.
    //
    // pr-build marks the single flavor a pull request builds, for half
    // the runner time. desktop rather than laptop because its gated
    // modules include the kvmfr DKMS build, so it covers more build
    // surface. Unrelated to default; they coincide today by choice.
    desktop default=#true pr-build=#true
    laptop
}

modules {
    module "core/bootloader"
    module "core/auto-updates"
    module "kernel/cachyos-kernel"

    module "cli-customizations" {
        fonts "JetBrainsMono" "FiraCode"
    }

    module "apps/affinity" variant="wine-only"

    // Inside a flavor block, every module is gated to that flavor.
    flavor "desktop" {
        module "virtualization/vfio-passthrough"
        module "virtualization/looking-glass"
    }

    flavor "laptop" {
        module "hardware/laptop-tweaks"
    }

    // Back outside, so ungated again, and it still builds above every
    // gated module: where a line sits only breaks ties.
    module "core/power-just-scripts"
}
```

One RUN layer per entry, in the order [Build order](#build-order)
resolves, which is document order wherever the graph says nothing.
Nesting rather than INI-style section headers makes "outside a flavor
block means ungated" structural instead of positional.

### `image`

What the image calls itself. The argument is its machine name, matching
`^[a-z][a-z0-9-]*$` because it becomes an image tag, a cache tag and the
default hostname.

| Child | Meaning |
| --- | --- |
| `name` | os-release `NAME`, the human one. Required. |
| `pretty-name` | os-release `PRETTY_NAME`. Defaults to `<name> <version>`. |
| `url` | os-release `HOME_URL` and `DOCUMENTATION_URL`. |
| `issues-url` | os-release `SUPPORT_URL` and `BUG_REPORT_URL`. |
| `logo` | scalable icon, installed into the hicolor theme. Its filename without the extension becomes os-release `LOGO`, so the two cannot name different icons. |
| `watermark` | plymouth boot splash watermark. |

os-release is the carrier, so this one declaration also reaches the GRUB
entry titles ostree writes and the desktop's about page. The published
image name comes from here too: `<name>` for the ungated build and
`<name>-<flavor>` for a flavor, which is what `scripts/flavors.sh`
answers with.

Asset paths are relative to the repository root and must be under
`brand/`, the one directory of theirs the build context carries. The
values reach the build as the `IMAGE_*` ARGs the phases below the module
layers read, and no module is given any of them: **a module never spells
the image out**. One that needs the brand at runtime reads
`/etc/os-release` on the running system, the way `core/goojust` names its
TUI alias.

Where the image *publishes* is deliberately not here. `scripts/registry.sh`
derives that from the git remote, so a fork follows its own with no edit,
and the finalize phase receives it as `IMAGE_REGISTRY`.

### `base`

The image every layer builds on, and what building on it may assume. The
argument is the full reference, emitted verbatim as the `FROM` in
`Containerfile.generated`: this file is the only place the base image is
named, so the declaration and the build cannot drift.

| Child | Meaning |
| --- | --- |
| `family` | which distro's packaging and tooling modules may assume. Checked against every enabled module's `supports`. Required. |
| `provides` | capabilities the base satisfies that no module could implement portably. A module may `require` one; nothing has to provide it. |
| `provides-file` | absolute paths to binaries the base guarantees. Checked on the finished image alongside the modules' own [contract files](#contract-files). |

Declared rather than derived. The family used to be recovered by looking
for the string `fedora` in the `FROM` line, which meant it could only
ever answer `fedora` and quietly did so even for an image that was not
Fedora at all. The capabilities used to be a constant in the checker,
populated after the modules were read, so a module declaring one of those
names shadowed the base with no duplicate-provider warning. Both are
decisions about the image, so both are made in the image author's file.

Renovate tracks the reference here through a custom manager, and the
`FROM` it produces in `Containerfile.generated` through the built-in
Dockerfile one; the two carry the same name and version, so a bump
updates both in a single PR.

### `flavors`

Each child node is one flavor name. Names match `^[a-z][a-z0-9-]*$`, must
be unique, and may not be `none` (see [Build targets](#build-targets)).

| Property | Meaning |
| --- | --- |
| `default=#true` | the flavor built when none is named. Exactly one, required when the block is present. |
| `pr-build=#true` | the single flavor a pull request builds. At most one; falls back to the default. |

Marked rather than inferred from position. Three unrelated policies had
already accumulated on "first entry" — the local build default, the PR
build flavor and nearly the installer image — and they collided because
one positional accident stood in for all of them.

**The block is optional.** Omitting it means one unnamed image: no
gating, `FLAVOR` unset, an unsuffixed image name, a single-element build
matrix, no sibling cache ref, one package to prune. That is the path a
stripped-down fork hits first, so it is the path that must work.

### `module`

```kdl
module "<path>" variant="<name>" {
    <option-name> <value...>
}
```

`<path>` is relative to `modules/`, and is the module's identity
everywhere. Quoted because a KDL 2.0 bare identifier cannot contain `/`.

| Property | Meaning |
| --- | --- |
| `variant=` | selects a `variant` block declared in the module's own manifest |

Children set options the module declares. A bare value list for a `list`
option, a single value otherwise:

```kdl
module "cli-customizations" {
    fonts "JetBrainsMono" "FiraCode"
    starship #true
}
```

A `source` child is not an option but a pin, and makes the entry an
[out-of-tree module](#out-of-tree-modules). An option by that name cannot
be set from the list, which is the one cost of spelling the pin here
rather than in a file of its own.

### Out-of-tree modules

A module that lives in another repository is pinned exactly, on its own
list entry. Absence of a `source` block means in tree, so nothing about
an existing entry changes.

```kdl
module "steam-tweaks" {
    source "https://github.com/owner/bootc-modules/archive/refs/tags/{ref}.tar.gz" {
        renovate datasource="github-tags" depName="owner/bootc-modules"
        ref "steam-tweaks/v1.2.0"
        sha256 "b7c232b0e8249d8e55a40beb79c5c43a7d370f3f9408bd215deb0170daeaadf3"
        path "modules/steam-tweaks"
    }
}
```

The entry's name is the module's identity everywhere: in the build
summary, in the finalize order and in every diagnostic. It is one path
segment, matching `^[a-z][a-z0-9-]*$`, and may not be the name of a
module in this repository.

| Node | Arity | Meaning |
| --- | --- | --- |
| `source "<template>"` | 0 or 1 | the archive to fetch. `{ref}` is the only expansion. |
| `renovate` | 0 or 1 | Renovate tracks this pin. Mutually exclusive with `manual`. |
| `manual "<why>"` | 0 or 1 | nothing tracks it, and this is why. Mutually exclusive with `renovate`. |
| `ref "<pin>"` | exactly 1 | the exact tag or commit the URL resolves against |
| `sha256 "<hex>"` | exactly 1 | what the fetched archive must hash to |
| `path "<subtree>"` | 0 or 1 | the module's directory inside the archive. Absent means the archive root is the module. |

**The hash is mandatory**, unlike an [asset pin](#asset-pins) where a
git ref stands in for one. A remote module is arbitrary shell running as
root in the build, so the guarantee worth having is that what runs is
what was reviewed. A changed `ref` whose archive does not hash to this
value fails at generate time, before anything is extracted.

`renovate` and `ref` follow the asset rules exactly: exactly one of
`renovate` and `manual`, and `ref` on the line directly below
`renovate`, because one regex in [renovate.json5](../.github/renovate.json5)
matches the two together. Only `github-tags` and `github-releases` are
accepted here. `git-refs` tracks a branch head, which needs the branch
name as well as the commit, and a module is published as a tag; a
repository with no tags is pinned `manual`.

The archive is a tar (`.tar.gz`, `.tgz`, `.tar.xz`, `.tar.zst`,
`.tar.bz2`). One leading directory is stripped, since a forge names it
for the ref, so `path` is relative to the repository root.

**Fetching happens at generate time**, on the host, into
`modules/.remote/<name>/`, which is gitignored.
[scripts/fetch-modules.sh](../scripts/fetch-modules.sh) does it and both
`just generate` and `just lint` call it; nothing about a build knows a
module came from elsewhere. The fetched tree lives under `modules/`
rather than beside the other generated output in `build/` because the
`ctx` stage copies `modules/`, and a `COPY` cannot be made conditional on
a directory that exists only once something is pinned.

What that buys, in order:

- the generator emits the same RUN block as for an in-tree module, so
  layer shape and cache behaviour are identical. The mount names
  `modules/.remote/<name>`, so which layers are third-party is visible in
  the committed `Containerfile.generated`.
- a remote module ships the same required `module.kdl` and is validated
  against the same schema before anything executes. Its `requires`,
  `secrets`, `packages`, options and collectors are data, reviewable
  before it runs.
- **no transitive fetching.** A remote module may `requires` a
  capability, and an unsatisfied one is the usual lint failure naming
  what would provide it. Providers are added by the image author, as
  everywhere else.

Nothing recurses and nothing resolves: there are no version ranges, no
lock file and no solver, so the pins in this file are the complete
statement of what is fetched.

### `flavor`

```kdl
flavor "<name>" {
    module "<path>"
}
```

Names a flavor declared in the `flavors` block; an undeclared one is an
error. Contains only `module` nodes. Flavor blocks may repeat, and a
module may appear under more than one flavor.

Flavor gating lives here and only here. A module never names a flavor.

## module.kdl

Required for every module. Absent, unparseable, or missing `description`
or `supports` is a lint failure.

```kdl
description "kvmfr DKMS module for Looking Glass GPU passthrough"

supports "fedora"

requires "kernel-devel"
requires-file "/usr/share/secureboot/sb_cert.der"
after "vfio"

secret "mok_privkey"
arg "KERNEL"
```

### Identity

| Node | Arity | Meaning |
| --- | --- | --- |
| `description "..."` | exactly 1 | one line, present tense, no trailing period. Shown in the resolved build summary. |
| `supports "<family>"` | 1+ | base families this module can build on. `fedora` is the only one today. |

No `version` field, ever. A module's version lives at its consumption
site, as the exact pin an out-of-tree entry carries, and in the
publishing repository's tags. Recording it here would create a second
place to keep in sync with no way to verify it.

### Capabilities

Depend on capabilities, not paths, so swapping a provider does not break
a consumer. A capability is a bare lowercase name, conventionally the
thing itself (`kernel-devel`, `plasma-desktop`), not the module offering
it.

| Node | Kind | Unsatisfied |
| --- | --- | --- |
| `provides "<cap>"` | — | — |
| `requires "<cap>"` | hard | error, naming every module that would satisfy it |
| `after "<cap>"` | soft | ignored |

`requires` implies ordering. `after` expresses ordering and cache
preference only, and never fails, so a module can prefer to run after an
optional peer without depending on it. There is no third edge kind: two
is enough to express everything in this repo, and each additional one
multiplies the sort's failure modes. What the two edges do to the build
order is [below](#build-order).

Nothing is auto-included. An unsatisfied `requires` names the modules
that would fix it and stops; it never adds one. The list stays the
complete statement of what is in the image.

### Contract files

A path one module writes and another reads. Generalises what the kernel
module and the finalize phase already do informally.

| Node | Meaning |
| --- | --- |
| `provides-file "<abs-path>"` | this module writes it |
| `provides-file "<abs-path>" build-only=#true` | it writes it for other build layers, then removes it again |
| `requires-file "<abs-path>"` | this module reads it, and fails without it |

The case this exists for: `modules/kernel/cachyos-kernel` ships
`/usr/share/secureboot/sb_cert.der`, and both `hardware/gaming` and
`virtualization/looking-glass` read it to sign their DKMS modules.
Dropping the kernel module from the list today leaves those two silently
shipping unsigned modules. Declared, it is a lint failure in seconds.

Distinct from a capability on purpose: a capability is satisfied by any
provider, a contract file is an exact path both sides agree on.

The [`base`](#base) node declares them too, for the binaries the base
image guarantees. They join the same union `manifest contract-files`
answers with, so the in-image check has one list to walk and no paths of
its own. They are not filtered by target: they are true of every image
built on that base.

`build-only` says how long the path lives, not whether it is a contract.
`/usr/libexec/kernel-devel-helpers.sh` is the one today: the kernel module
writes it, both DKMS consumers `requires-file` it, and the kernel module's
finalize hook removes it once they have built. So it is a real contract
that a correct image does not contain, and the two claims have to be
separable. A `build-only` path still binds build order and still fails
lint when its provider is delisted; what changes is that the in-image
validation does not assert it exists, which it reaches through `manifest
contract-files`. Only `provides-file` takes the property: reading or
overriding a path says nothing about its lifetime, and declaring it there
is an error rather than a no-op.

### Overlay collisions

Every `files/` overlay is copied over the image root in build order, so
two modules shipping the same path means the later one wins and the
earlier one's file never reaches the image. Nothing about that is
visible in either module, so it is an error.

| Node | Meaning |
| --- | --- |
| `overrides "<abs-path>"` | this module's overlay knowingly replaces a path an earlier module ships |

Checked both ways. Without it a collision fails; with nothing to
override it fails too, so the escape hatch cannot outlive the collision
it was added for. Two modules gated to different flavors never land in
the same image, so they are not a collision.

There are zero collisions today, which is why the check and the escape
hatch arrive together: an escape hatch with nothing to escape, and no
check to escape from, would be surface nothing could verify.

### Collecting

A module that wants every copy of a filename in the image says so, and
says where the build should put them. Any module shipping that filename
contributes.

```kdl
// modules/core/goojust/module.kdl
collects "justfile.inc" into="/usr/share/goojust/justfile.apps"

// modules/core/flatpak/module.kdl
collects "flatpaks.list" into="/usr/share/flatpak-defaults/apps.list"
```

| Part | Meaning |
| --- | --- |
| argument | filename in a contributing module's directory |
| `into=` | absolute destination in the image, created if needed |

**The declaration says nothing about what the collecting module then does
with them.** The build collects; interpreting the result is the module's
business. Today the build appends, in build order, but that is a
detail of the collector and not a promise of this node — which is why it
is not called `aggregates` or `concatenates`.

Contribution is presence driven, like `files/` and `selinux/`: shipping
the file is the whole contribution and a contributor declares nothing.
Only the destination is declared, because it is the one part that cannot
be derived from the filename.

This is what removes the hardcoded goojust and flatpak paths from the
runner: any module can start collecting a new filename, and the runner
learns about it from resolved env. Only the pairs a module actually
contributes reach its layer, so a module that contributes nothing carries
no such env at all.

One collector per filename, or where a contribution went would depend on
build order. A module shipping a collected filename while the
module that collects it is absent is an error — it would otherwise be
silently ignored, which is how a contribution goes missing without
anything failing.

### Options

Typed, declared by the module, set by the image author, passed as env.
Turns hardcoded lists inside a module's own script into a configurable
surface.

```kdl
option "fonts" type="list" {
    description "Nerd Font families to install"
    default "JetBrainsMono" "FiraCode" "CascadiaMono"
}

option "starship" type="bool" {
    description "Install the starship prompt"
    default #true
}
```

| Type | KDL value | Env value |
| --- | --- | --- |
| `string` | `"text"` | verbatim |
| `bool` | `#true` / `#false` | `1` / `0` |
| `list` | zero or more strings | space joined |

Option names are kebab-case. The env name is the option name uppercased
with dashes as underscores, prefixed `OPT_`: `gpu-accel` becomes
`OPT_GPU_ACCEL`.

A `list` value may not contain whitespace, because the env encoding joins
on spaces. Validated, so an offending value fails at lint rather than
splitting silently inside the build.

`default` is required — an option with no default is a required argument
in disguise, which `requires` already expresses better.

**Resolution is a single pass**, in this order, with no merging:

1. the module's declared `default`
2. the selected `variant`'s `set`
3. the value in `image.kdl`

Only the image author sets options, and only on the owning module's own
entry. A module cannot set another module's option, so there are no merge
priorities, no fixpoint evaluation and no resolution order to reason
about. Setting the same option twice on one entry is an error, not a
merge.

### Variants

A named bundle of option overrides, declared by the module and selected
by the image author.

```kdl
variant "wine-only" {
    description "Skip the WinRT metadata and .NET payloads"
    set "dotnet" #false
    set "winmd" #false
}
```

A variant may only `set` options the same manifest declares. Selecting an
undeclared variant is an error.

This replaces `variants/*.sh`, which overrode pins by reassigning shell
variables inside the build. Variants now resolve on the host into option
env, so nothing inside the image sources a variant file and the runner
loses the concept entirely. It cannot override an [asset
pin](#asset-pins): a pin is not an option, and no module needs a variant
to move one, so the form for saying so would be surface nothing could
verify. That is the extension to make when one does.

### Asset pins

An asset is a pinned upstream input: a release archive, a single file, or
a git ref a module clones. Everything about the pin is declared here, and
the generator passes the resolved values to the layer as env.

```kdl
asset "starship" {
    renovate datasource="github-releases" depName="starship/starship"
    version "1.26.0"
    url "https://github.com/starship/starship/releases/download/v{version}/starship-x86_64-unknown-linux-musl.tar.gz"
    sha256 "b7c232b0e8249d8e55a40beb79c5c43a7d370f3f9408bd215deb0170daeaadf3" from="sidecar"
}
```

| Node | Arity | Meaning |
| --- | --- | --- |
| `renovate` | 0 or 1 | Renovate tracks this pin. Mutually exclusive with `manual`. |
| `manual "<why>"` | 0 or 1 | nothing tracks it, and this is why. Mutually exclusive with `renovate`. |
| `version "<pin>"` | 0 or 1 | the pinned ref: a version, a tag or a commit. Required with `renovate`. |
| `url "<template>"` | 0 or 1 | download URL. `{version}` is the only expansion. |
| `sha256 "<hex>"` | 0 or 1 | what the fetched bytes must hash to. |

The asset name is kebab-case and unique within the module. It becomes an
env prefix, uppercased with dashes as underscores: `nerd-fonts` arrives as
`ASSET_NERD_FONTS_VERSION`, `_URL` and `_SHA256`, one per field that is
declared. A field that is not declared contributes no env, so a module
reading it fails under `set -u` rather than fetching an empty URL.

**`url` and `sha256` come together.** A download with nothing to check it
against looks pinned while installing whatever the URL serves today. A
module that clones a git ref instead declares neither: nothing is
downloaded, and `git checkout <commit>` cannot hand back other content.

`from=` on `sha256` says where the expected hash comes from when a
version bump makes the pinned one stale. Only the [checksum
workflow](../.github/workflows/checksums.yml) reads it; the build always
verifies against whatever is pinned here.

| `from=` | Where the hash comes from |
| --- | --- |
| `"asset"` (default) | hashing the asset itself. Trust-on-first-use, taken at PR time, which still catches an asset swapped after the pin was made. |
| `"sidecar"` | the `<url>.sha256` upstream publishes beside it, so the pin is accurate from the start. |
| `"manual"` | a human. For an asset whose filename does not follow from its version, or that has no version at all. |

#### What Renovate reads

`renovate` carries Renovate's own field names, and Renovate reads them out
of this file directly through the custom managers in
[renovate.json5](../.github/renovate.json5).

| Property | Meaning |
| --- | --- |
| `datasource=` | `github-releases`, `github-tags` or `git-refs` — the three the custom managers match |
| `depName=` | `owner/repo`, or the clone URL for `git-refs` |
| `extractVersion=` | Renovate's capture turning an upstream tag into the value pinned here, e.g. `^v(?<version>.*)$` |

Declared as data rather than written in a comment, because a comment
cannot be checked and this one silently stopped matching through two path
moves. The pin still has to be **flat and adjacent**: `version` is a line
of its own directly below `renovate`, since the two are matched by one
regex. Both halves are validated — an unsupported datasource, a missing
`depName`, or anything wedged between the two lines fails lint rather than
leaving the pin quietly unmanaged.

An asset with no upstream to watch says so with `manual` and says why.
Absence is not a mark: the next reader takes a missing annotation for an
oversight and wires it up, which is exactly what the reason exists to
prevent.

### Packages

Declared packages as well as calling the installer directly, so the
generator emits one batched transaction per layer, package sets lint can
inspect, and adding a second base family later is a data change in one
place: the module manifest.

Additive, never a replacement. A module keeps `dnf5 install -y` in
`module.sh` whenever it prefers, and most of them do. The declaration
exists for the modules where a flat list is genuinely all there is, and
says nothing about the rest.

```kdl
packages {
    fedora "just" "fastfetch"
    fedora "tailscale" enablerepo="tailscale-stable"
}
```

Each child node names a base family and carries the package names as
positional arguments. On Fedora the generator emits `dnf5 install -y`
for each unique (family, enablerepo) group; a second family would pick
its own verb.

| Property | Meaning |
| --- | --- |
| `enablerepo=` | install from a repo the base image already carries disabled. Not the module's own `repo` file: that is sourced by `run-module.sh`, after the generated install runs. |

A module that ships a `repo` file cannot declare `packages` at all, and
lint says so. The repo does not exist yet when the generated install
runs, so the two together are always a build failure; `dnf5 install -y`
in `module.sh` is where those packages belong, and with the declaration
additive nothing is lost by refusing the combination.

Only the family the build targets is emitted, and the family name has to
be one this repository knows. A package list for another known family
sits harmlessly in the manifest until that family becomes a build target.

Package names and repo IDs go straight into the RUN line, so both are
limited to letters, digits and `. _ + : -`, and neither may start with a
dash or be a non-string. That covers what an RPM spec legitimately holds
(`gcc-c++`, `python3.12`, an epoch like `pkg-1:2.3`, a copr repo ID) and
excludes everything that means something to the shell. Anything outside
it belongs in `module.sh`, where it can be quoted deliberately.

A module with complex package operations (group install, remove, copr
enable, distro-sync, versionlock) keeps those in `module.sh`. The
declaration covers the simple case — one batched install per layer —
which is most of them.

Packages are installed before `module.sh` runs, chained with `&&`, so a
failure stops the layer and the module's own script still executes.

### Build inputs

The parameters a module needs from the build itself. These exist because
a module needing a secret or a build arg should not have to hand-write a
whole RUN block to get one.

| Node | Emits |
| --- | --- |
| `secret "<id>"` | `--mount=type=secret,id=<id>,target=/run/secrets/<id>,required=false` |
| `arg "<NAME>"` | `<NAME>=${<NAME>}` in the layer's env prefix |

`required=false` always: a build without the secret is a supported build
that skips what the secret enables, and the alternative is a repository
that only its owner can build.

**A module asks for a secret, it never picks one.** The ID names what the
module wants; whether this repository is willing to hand it over is the
build workflow's `SECRET_` env list, one line per secret it allows.
`secret "mok_privkey"` is satisfied by `SECRET_MOK_PRIVKEY`, wired to the
`MOK_PRIVKEY` repository secret. Adding a secret to a module is a
manifest line, a repository secret and one workflow line.

The allowlist is the point, not overhead. A manifest is data, and Stage
10 accepts manifests from outside this repository, so an ID that selected
its own value would let a module name a secret it has no business reading
and have it mounted into a layer it controls. An ID must also be
`[a-z0-9_]`, since it becomes a variable name and a filename. A declared
ID the list does not cover is a warning and an absent file, which is the
`required=false` case above.

An `arg` must be declared somewhere above the module's layer, or the
generator fails rather than expanding it to an empty string.

`mount` and `env` nodes are deliberately absent. No module needs either
today, and unused schema surface cannot be verified. They are the obvious
next additions when one does.

### Raw fragments

A module needing something the field sets cannot express — an extra
builder stage, a second layer, an `ARG` with a default — ships a
`Containerfile.inc`, which the generator inlines verbatim *alongside* the
standard block.

Shipping the file is the whole declaration, as with `files/`. The
optional `fragment` node carries only the two things the file cannot say
about itself:

```kdl
fragment position="after" standard-layer=#false
```

| Property | Default | Meaning |
| --- | --- | --- |
| `position=` | `"before"` | where the fragment goes relative to the generated block |
| `standard-layer=` | `#true` | whether that block is emitted at all |

Because a fragment adds rather than replaces, a module ships only the
part it actually needs: `kernel/cachyos-kernel`, the one module with a
fragment today, is down to its `ARG KERNEL=cachyos` — graph shape rather
than a parameter, and the line the kernel-freshness workflow rewrites to
fall back to the stock kernel. Its mounts, its build arg and its signing
secret are declared, and the generator writes the same RUN line the
fragment used to spell out by hand.

`standard-layer=#false` asks for the full override the generator used to
do implicitly: the fragment becomes the only thing the module emits, and
it has to call `run-module.sh` itself and mount everything that needs.
Nothing then carries the module's `secret`, `arg`, `option` or collected
files, so declaring any of those alongside it is an error rather than a
silent omission — the hole the old replacing behaviour left, where a
declared option was quietly dropped.

A fragment is emitted unconditionally: the generated Containerfile is one
file for every target, and the only per-flavor mechanism is the
`FLAVOR_GATE` the runner checks. The standard block carries the gate, so
a gated module's fragment only has to when it runs a command of its own,
which lint checks against the flavor block the module is listed under.

## Build order

Resolved from the graph, not read off the list. A `requires` already
says "after whatever provides this", so the list does not have to repeat
it and the two can no longer disagree.

Constraints, in the order they bind:

1. a provider builds before anything that `requires` it or reads a file
   it `provides-file`s. Hard.
2. a provider builds before anything declaring `after` it, when it is
   enabled at all. Soft, and skipped when it would drag an ungated
   module below the flavor gate — a preference is not worth a layer per
   flavor.
3. ungated modules build before gated ones, so nothing lands below `ARG
   FLAVOR` and gets built once per target for no reason.
4. anything still tied builds in declaration order.

**Determinism is not negotiable**: the same list produces the same order
on every machine, because a reshuffle is a full rebuild. That is also
why there is no `weight` field. Declaration order is already the
tie-break, and image.kdl is the image author's file, so wanting one
module later is expressed by moving its line — a second knob for the
same thing would only be a way for the two to disagree.

A cycle has no build order at all, so it is a lint failure naming the
edges that close it.

The resolved order is what the committed `Containerfile.generated`
shows, layer by layer, and what `manifest summary` prints.

## Build targets

A **flavor** is an image build variant. A **target** is something the
matrix builds, which is every flavor plus the ungated set.

The image column is the [`image`](#image) name, suffixed per flavor:

| Target | Image | Cache tag | `FLAVOR` |
| --- | --- | --- | --- |
| `none` | `<image>` | `none` | unset |
| `desktop` | `<image>-desktop` | `desktop` | `desktop` |
| `laptop` | `<image>-laptop` | `laptop` | `laptop` |

`none` is a reserved token, not a flavor, and is rejected as a flavor
name. It exists because a cache tag and a matrix entry both need a
spellable name, and because calling the ungated set a flavor would
reintroduce the hand-maintained device-neutral alias that was already
rejected.

The ungated set is published unsuffixed and needs no declaration: it
exists because the ungated set exists. Everything above `ARG FLAVOR` is
already shared, so it costs no extra layers, and it makes the
no-flavors path continuously built rather than a degenerate case that
rots. A gated module still emits a layer in this build; the layer sees an
empty `FLAVOR`, skips, and costs nothing.

The installer ISO targets the ungated set **by rule**, not by a maintained
value. Kargs under `/usr/lib/bootc/kargs.d/` are static and cannot be
made conditional on hardware, so an installer payload must be the ungated
set; moving to a device flavor afterwards is a `bootc switch`, made cheap
by rechunking.

## What the layer sees

The generator resolves everything on the host and passes results down.
Nothing inside the image parses KDL.

| Env | When |
| --- | --- |
| `FLAVOR_GATE=<flavor>` | the entry is inside a `flavor` block |
| `OPT_<NAME>=<value>` | one per declared option, always, defaults included |
| `ASSET_<NAME>_VERSION`, `_URL`, `_SHA256` | one per declared asset field, URL already resolved |
| `MODULE_COLLECT="<file>=<dest> ..."` | this module ships a file another module collects |
| `<NAME>=${<NAME>}` | one per `arg` |

Plus `MODDIR` as the runner's argument, and one secret mount per
`secret`.

The finalize phase gets `FINALIZE_ORDER`, a space-separated list of
`<path>` or `<path>:<flavor>` tokens in resolved order, so it no longer
reparses the module list inside the image. That parser was the second
implementation of the list format and could drift from the first.

## Validation

Lint fails on all of these, in seconds, before anything builds.

**Structure**

- either file unparseable, or carrying a node or property this schema
  does not define
- an `image.kdl` entry that does not resolve to a module directory
- a module directory without a `module.kdl`, or one missing
  `description` or `supports`
- no `image` node, an `image` declared twice, one with no name, no
  `name` child, a name outside `^[a-z][a-z0-9-]*$`, or an asset path
  outside `brand/` or naming a file that does not exist
- no `base` node, a `base` declared twice, one with no image reference or
  no `family`, or a `provides-file` on it that is not an absolute path
- an enabled module whose `supports` does not include the base `family`

**Flavors**

- a flavor name outside `^[a-z][a-z0-9-]*$`, duplicated, or named `none`
- a `flavors` block with no `default=#true`, or with more than one
- more than one `pr-build=#true`
- a `flavor` block naming an undeclared flavor

**Graph**

- a `requires` no enabled module provides, listing every module that
  would satisfy it
- a `requires-file` no enabled module provides
- two enabled modules providing the same capability or contract file
- a module providing something the `base` node already provides
- a module shipping `selinux/*.te` without `requires "mac-policy"`
- a requirement satisfied only by a module gated to another flavor
- a cycle, naming the edges that close it

**Overlays**

- two enabled modules that land in the same image shipping the same
  `files/` path, without the later one declaring `overrides`
- an `overrides` for a path no earlier module ships

**Collecting**

- shipping a collected filename while the module that collects it is not
  enabled
- two enabled modules collecting the same filename

**Asset pins**

- an asset declaring neither `renovate` nor `manual`, or both
- a `renovate` with no `depName`, or a datasource no custom manager
  matches
- a `renovate` with no `version` below it, or with something between the
  two
- a `manual` with no reason
- a `url` without a `sha256`, or a `sha256` without a `url`
- a `sha256` that is not 64 lowercase hex digits
- a `url` holding a placeholder other than `{version}`, or holding
  `{version}` with no version pinned
- two assets in one module under the same name
- a `version` or `url` containing a shell metacharacter, which the env
  prefix would not survive

**Options and variants**

- setting an option the module does not declare, or setting one twice
- a value that does not match the declared type
- a `list` value containing whitespace
- selecting an undeclared variant, or a variant setting an undeclared
  option

**Fragments**

- a `fragment` node in a module that ships no `Containerfile.inc`, or
  one declared twice
- a `position` other than `before` or `after`, or one declared alongside
  `standard-layer=#false`, where there is nothing to be before or after
- a `secret`, `arg`, `option`, `asset` or collected file declared
  alongside `standard-layer=#false`, which removes the layer they would
  land on
- a `Containerfile.inc` expanding `FLAVOR` above the `ARG FLAVOR`
  declaration
- a gated module whose fragment runs a command without carrying the
  matching `FLAVOR_GATE`

**Out-of-tree pins**

- a pin declaring neither `renovate` nor `manual`, or both
- a `renovate` with something between it and the `ref` below it, or
  naming `git-refs`
- a pin with no `ref`, or no `sha256`
- a `sha256` that is not 64 lowercase hex digits
- a source URL that is not https or file, is not a tar archive, holds a
  placeholder other than `{ref}`, or omits `{ref}` while tracked
- a subtree `path` that is absolute or holds a `..` segment
- a pinned name that is not one lowercase path segment, or that is also
  a module in this repository
- a URL, ref or path holding a character the fetch could not carry
- an option named `source`, which a list entry's pin already claims

## Not implemented yet

Deliberately out of scope, recorded so the shapes above are not mistaken
for oversights. Each is additive: none of them changes a node defined
here.

- **A variant overriding an asset pin.** A pin is not an option, and no
  module needs a variant to move one.
