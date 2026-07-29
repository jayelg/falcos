[root](../README.md) / [modules](README.md) / **manifest schema**

The declared interface between a module and everything outside it. Two
files, one parser ([tools/manifest](../tools/manifest), reached through
[scripts/manifest.sh](../scripts/manifest.sh)), both KDL 2.0.

- **[modules.kdl](../modules.kdl)** — the image author's file. Which
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
| `versions.sh` | sourced for Renovate-tracked pins |
| `selinux/*.te` | compiled and installed at priority 200 |
| `files/` | copied verbatim into the image |
| `finalize.sh` | sourced by the finalize phase, in resolved order |
| a file matching a declared `sink` | appended to that sink |

A manifest declares *facts*, not *file layout*.

## modules.kdl

Two top-level nodes. `flavors` is optional; `modules` is required.

```kdl
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
    module "base"
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

    // Back outside, so ungated again. A module here is built once per
    // flavor because it sits below ARG FLAVOR; put one here only when it
    // must run after every gated module.
    module "core/power-just-scripts"
}
```

Order is document order, top to bottom, and is the build order: one RUN
layer per entry. Nesting rather than INI-style section headers makes
"outside a flavor block means ungated" structural instead of positional.

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

**Reserved, and an error if used.** Out-of-tree modules are planned, and
these are the fields they need, claimed now so adding them later is not a
format change:

| Property | Will mean |
| --- | --- |
| `source=` | repository to fetch the module from |
| `ref=` | exact commit or tag |
| `sha256=` | hash of the fetched archive |

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
requires-file "/usr/share/falcos/sb_cert.der"
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
multiplies the sort's failure modes.

Nothing is auto-included. An unsatisfied `requires` names the modules
that would fix it and stops; it never adds one. The list stays the
complete statement of what is in the image.

### Contract files

A path one module writes and another reads. Generalises what the kernel
module and the finalize phase already do informally.

| Node | Meaning |
| --- | --- |
| `provides-file "<abs-path>"` | this module writes it |
| `requires-file "<abs-path>"` | this module reads it, and fails without it |

The case this exists for: `modules/kernel/cachyos-kernel` ships
`/usr/share/falcos/sb_cert.der`, and both `hardware/gaming` and
`virtualization/looking-glass` read it to sign their DKMS modules.
Dropping the kernel module from the list today leaves those two silently
shipping unsigned modules. Declared, it is a lint failure in seconds.

Distinct from a capability on purpose: a capability is satisfied by any
provider, a contract file is an exact path both sides agree on.

### Aggregation sinks

A module that owns an aggregated file declares where it lands and which
filename feeds it. Any module shipping that filename contributes to it.

```kdl
// modules/core/goojust/module.kdl
sink "justfile" file="justfile.inc" path="/usr/share/goojust/justfile.apps"

// modules/core/flatpak/module.kdl
sink "flatpaks" file="flatpaks.list" path="/usr/share/falcos/default-flatpaks"
```

| Property | Meaning |
| --- | --- |
| `file=` | filename in a contributing module's directory |
| `path=` | absolute destination in the image, created if needed |

Contributions are appended in module list order. This is what removes the
hardcoded goojust and flatpak paths from the runner: any module can
define a new sink, and the runner learns about it from resolved env.

Sink names and sink filenames must both be unique across enabled modules.
A module shipping a file that matches no declared sink is an error — it
would otherwise be silently ignored, which is how a contribution goes
missing without anything failing.

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
3. the value in `modules.kdl`

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
loses the concept entirely. Once asset pins move into this manifest, a
variant overrides a pin the same way it overrides any other option.

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

An `arg` must be declared somewhere above the module's layer, or the
generator fails rather than expanding it to an empty string.

`mount` and `env` nodes are deliberately absent. No module needs either
today, and unused schema surface cannot be verified. They are the obvious
next additions when one does.

### Overlay overrides

```kdl
overrides "core/goojust"
```

Declares that this module's `files/` overlay intentionally replaces a
path an earlier module shipped. There are zero collisions today; the node
exists so the planned overlay collision check has an escape hatch that
keeps deliberate mutation possible but visible.

### Raw fragments

A module needing something the field sets cannot express — an extra
builder stage, a second layer, an `ARG` with a default — ships a
`Containerfile.inc`, which the generator inlines verbatim *instead of*
the standard block.

Because it replaces the block rather than adding to it, a module with a
`Containerfile.inc` may not also declare `secret` or `arg`: the fragment
already spells those out itself, and a declaration it silently ignored
would be worse than no declaration. Lint enforces this. Fragments are
planned to become additive rather than replacing, at which point the two
combine and this restriction lifts.

One module uses one today: `kernel/cachyos-kernel` declares `ARG
KERNEL=cachyos`, which is graph shape rather than a parameter, and is the
line the kernel-freshness workflow rewrites to fall back to the stock
kernel.

## Build targets

A **flavor** is an image build variant. A **target** is something the
matrix builds, which is every flavor plus the ungated set.

| Target | Image | Cache tag | `FLAVOR` |
| --- | --- | --- | --- |
| `none` | `falcos` | `none` | unset |
| `desktop` | `falcos-desktop` | `desktop` | `desktop` |
| `laptop` | `falcos-laptop` | `laptop` | `laptop` |

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

The installer ISO targets `falcos` **by rule**, not by a maintained
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
| `MODULE_SINKS="<file>=<path> ..."` | any enabled module declares a sink |
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
- a `modules.kdl` entry that does not resolve to a module directory
- a module directory without a `module.kdl`, or one missing
  `description` or `supports`

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

**Sinks**

- a `contributes`-shaped file matching no declared sink
- two enabled modules declaring the same sink name or sink filename

**Options and variants**

- setting an option the module does not declare, or setting one twice
- a value that does not match the declared type
- a `list` value containing whitespace
- selecting an undeclared variant, or a variant setting an undeclared
  option

**Fragments**

- a module declaring `secret` or `arg` alongside a `Containerfile.inc`
- a `Containerfile.inc` expanding `FLAVOR` above the `ARG FLAVOR`
  declaration

**Reserved**

- `source`, `ref` or `sha256` on a list entry

## Not implemented yet

Deliberately out of scope, recorded so the shapes above are not mistaken
for oversights. Each is additive: none of them changes a node defined
here.

- **Ordering by the graph.** The build order is document order today. A
  deterministic topological sort over `requires` and `after` replaces it,
  tie broken by declaration order, along with the rule that ungated
  modules sort above gated ones so nothing lands below `ARG FLAVOR` and
  gets built once per flavor for no reason. Determinism is not
  negotiable: a reshuffle is a full rebuild.
- **Additive fragments.** `Containerfile.inc` gains a declared position
  and stops replacing the generated block, which is what lets the
  restriction on `secret` and `arg` lift.
- **The overlay collision check** that gives `overrides` its purpose.
- **`asset` blocks replacing `versions.sh`**: datasource, version,
  sha256, URL template and verify mode, one block per asset. Pins must
  stay Renovate-readable, so an asset's version has to be a flat
  `version "x.y.z"` line with its annotation comment directly above; a
  nested pin form stops matching silently.
- **`packages { fedora "..." }`**, declaring packages instead of calling
  the installer, and `supports` becoming enforced against the base family
  rather than merely declared.
- **`source`, `ref` and `sha256`** on list entries, for out-of-tree
  modules.
