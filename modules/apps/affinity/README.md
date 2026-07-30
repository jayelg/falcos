# Affinity

Affinity v3 (Canva unified app: Photo, Designer, Publisher) baked into the
image under a patched WoW64 Wine build.  The Wine build, PE DXVK and
vkd3d-proton DLLs, WinRT metadata, wintypes shim, VC++ redistributable,
.NET 4.8 offline installer, and the launcher are all image-staged.  The
mutable per-user prefix is created by `falcos affinity-setup`.

## Build

At image build time:
- `dnf5 install -y winetricks clinfo zstd 7zip`
- Downloads and verifies the patched Wine tarball, DXVK, vkd3d-proton,
  WinMD, wintypes shim, VC++ redist, and .NET 4.8 offline installer.
- Installs Wine to `/usr/lib/wine-affinity/`, DLLs and metadata to
  `/usr/share/wine-affinity/`.
- Creates `/usr/bin/affinity` launcher (env -u LD_PRELOAD,
  RUSTICL_ENABLE=radeonsi,iris).

## Files installed

- `/usr/bin/affinity`
- `/usr/lib/wine-affinity/`
- `/usr/share/wine-affinity/`
- `/usr/libexec/affinity-sync-prefix`
- `/usr/share/applications/affinity.desktop`
- `/usr/share/icons/hicolor/scalable/apps/affinity.svg`
- `/usr/lib/systemd/user/affinity-sync.service`

## Runtime

Run `falcos affinity-setup` once per user to create the Wine prefix.

### Justfile recipes

- `falcos affinity-setup` -- Create the per-user Wine prefix
- `falcos affinity-remove` -- Remove the per-user Wine prefix
