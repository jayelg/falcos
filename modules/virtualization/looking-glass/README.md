[root](../../../../README.md) / [build-phases](../../../../build-phases/README.md) / [modules](../../README.md) / **looking-glass**

Builds both halves of Looking Glass from one clone of the upstream tree at the pinned tag: the `kvmfr` DKMS module, the shared-memory transport between the host and a GPU-passthrough VM, and `looking-glass-client`, which displays the guest's frames. Desktop flavor only (gated by the `flavor "desktop"` block in [image.kdl](../../../image.kdl)); the matching VFIO kargs, modprobe config and rebind service ship in the `vfio-passthrough` module.

- The `looking-glass` asset in `module.kdl` pins the upstream release tag; the module version is read from upstream's `dkms.conf` at that tag, so there is no second version to keep in sync.
- `files/` ships the udev rule granting the `kvm` group access to `/dev/kvmfr0`.
- Signed with the MOK key when the build supplies one, like the kernel and xone modules.

## Reaching the shared memory

Both transports are owned by the `kvm` group, so everything here is about a desktop user being in it and the memory existing before QEMU decides who owns it.

- `kvm-group-membership.service` adds every `wheel` member to `kvm` at boot, the same shape as `libvirt-group-membership.service` in the `libvirt` module. Its helper writes the group into `/etc/group` first, because `kvm` is one of the image's own groups and ships in `/usr/lib/group`: it resolves through `getent` but is invisible to `usermod`, which reads `/etc/group` and nothing else. Being in `kvm` grants nothing on `/dev/kvm` that the mode does not already give everyone (`0666 root:kvm`); it is what makes the two paths below reachable.
- `tmpfiles.d` creates `/dev/shm/looking-glass` as `qemu:kvm 0660`. Left to QEMU the file appears as `qemu:qemu 0644`, and the client, which maps it read-write as the desktop user, gets `Permission denied`. `/dev/shm` is a tmpfs, so a one-off `chown` does not survive a boot and this has to be declared.
- `looking-glass-shm-relabel.service` then sets the file's SELinux type to `svirt_tmpfs_t`. Declaring the file moves who creates it, and with it the label: `systemd-tmpfiles` gets the default context for `/dev/shm`, `tmpfs_t`, which `svirt_t` cannot open, so QEMU fails with `Permission denied` where the DAC bits are plainly fine. The distribution policy carries no file context for anything under `/dev/shm`, so `restorecon` has nothing to restore and `tmpfiles.d` has no field for a context, which is why this is a unit rather than one more line of configuration. Same shape as `libvirt-relabel.service` in the `libvirt` module.

`kvmfr` is the other transport and is not wired up: nothing loads the module, so `/dev/kvmfr0` never appears and the udev rule above never fires. Loading it wants `options kvmfr static_size_mb=<size>` and a `modules-load.d` entry here, and a domain XML that passes the device instead of a `<shmem>` file.

## The client

Nobody packages it: it is not in Fedora or RPM Fusion, there is no Flathub app, and the COPRs that carry it are personal. Upstream ships source, so the module builds it, which also means the client and the kernel module can never be on different releases.

- Built with cmake into `/usr`, because the default `/usr/local` is a symlink into `/var` on a bootc image.
- The clone is `--recurse-submodules` for it; kvmfr alone does not need them.
- `provides-file "/usr/bin/looking-glass-client"` puts the binary under the finished-image check, which is the only thing asserting a source build that quietly produced nothing.

Two things upstream's own instructions do not cover, both from Fedora 44 being newer than the B7 release:

- `-Wno-error=maybe-uninitialized`, because GCC 16 reports one in the vendored nanosvg header and the client's `CMakeLists.txt` hardcodes `-Werror`. The narrow form is required: GCC gives the more specific option priority whatever its position, while a bare `-Wno-error` loses to the `-Werror` that follows it.
- `-lzstd` and `libzstd-devel`, because Fedora's static `libbfd` needs zstd and the client's backtrace support links it without. `-DENABLE_BACKTRACE=no` is the alternative and gives up the backtrace on a crash.

Its build dependencies come from upstream's Debian list, with `libXrandr-devel` added because Fedora's `libXpresent-devel` does not pull it in and `Xpresent.h` includes `Xrandr.h`, and `pkg-config` left out because the base ships it and `kmod` depends on it, so removing it is not possible.

They are removed with `--noautoremove`, the same shape as Darkly in `de/kde-theming`, which leaves roughly 95 MB of headers (`libstdc++-devel` and `glib2-devel` most of it) that plain removal would have collected. Plain removal would also collect `libsamplerate`, which nothing else in the image requires and the client's audio backend links against, so the image would ship a client that cannot start.
