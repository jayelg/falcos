# Set up the Affinity v3 Wine prefix for this user (Wine and DLLs ship in the image; run once)
[group('Apps')]
affinity-setup:
	#!/usr/bin/env bash
	set -eou pipefail
	source /usr/share/falcos/falcos-helpers.sh

	export WINEPREFIX="$HOME/.local/share/affinity"
	export WINE=/usr/lib/wine-affinity/bin/wine
	export WINESERVER=/usr/lib/wine-affinity/bin/wineserver
	export PATH="/usr/lib/wine-affinity/bin:$PATH"
	unset LD_PRELOAD

	echo "==> Initialising Wine prefix at $WINEPREFIX..."
	# Suppress wine-mono/gecko install dialogs — winetricks removes mono and
	# installs core fonts, tahoma, and sets renderer=vulkan.  dotnet48 is not
	# installed via winetricks because the dotnet40 prerequisite needs syswow64
	# (32-bit) support that this WoW64 Wine build lacks — it is installed from
	# the baked-in offline installer below.  Same for vcrun2022.
	WINEDLLOVERRIDES="mscoree,mshtml=" wineboot --init
	# Kill wineserver: lingering services (e.g. services.exe on this WoW64
	# build) stay resident and cause later wineserver -w calls (winetricks
	# calls it between verbs) to hang indefinitely.
	"$WINESERVER" -k

	# WoW64-only build has no syswow64 directory; winetricks corefonts
	# and tahoma call C:\windows\syswow64\regedit.exe to import .reg
	# font registration files.  On both standard and WoW64 Wine the
	# regedit stub lives at C:\windows\regedit.exe, not system32.
	mkdir -p "$WINEPREFIX/drive_c/windows/syswow64"
	REGEDIT_SRC="$WINEPREFIX/drive_c/windows/regedit.exe"
	if [ -f "$REGEDIT_SRC" ]; then
		cp "$REGEDIT_SRC" "$WINEPREFIX/drive_c/windows/syswow64/regedit.exe"
	else
		echo "Warning: regedit.exe stub not found at $REGEDIT_SRC; font registration may fail" >&2
	fi

	echo "==> Installing Windows components via winetricks (slow, downloads ~1 GB)..."
	# dotnet48 and vcrun2022 are not installed via winetricks because their
	# prerequisites need syswow64 (32-bit) support that this WoW64 Wine build
	# lacks.  Both are installed from baked-in offline installers below.
	# --no-isolate skips winetricks' between-verb wineserver -w calls which
	# hang on this WoW64-only Wine build when a service stays resident.
	winetricks --unattended --force --no-isolate remove_mono corefonts win11 tahoma renderer=vulkan

	# .NET 4.8 offline installer (baked into the image, replaces winetricks
	# dotnet48 which would call the failing dotnet40 prerequisite).
	# The self-extractor is a 32-bit PE and its bootstrapper needs syswow64
	# support that this WoW64 Wine build lacks, so we extract the x64 MSI
	# with 7z and install it directly via Wine's 64-bit msiexec.
	echo "==> Installing .NET 4.8 from the baked-in offline installer..."
	DOTNET48_TMP=$(mktemp -d)
	7z x /usr/share/wine-affinity/ndp48-x86-x64-allos-enu.exe -o"$DOTNET48_TMP" -y >/dev/null 2>&1
	X64_MSI=$(find "$DOTNET48_TMP" -name '*x64*.msi' -o -name '*amd64*.msi' 2>/dev/null | head -1)
	winecfg -v win7
	if [ -n "$X64_MSI" ]; then
		WINEDLLOVERRIDES=fusion=b "$WINE" msiexec /i "$X64_MSI" /q /norestart
	else
		echo "  x64 MSI not found in extracted installer, trying direct self-extractor..."
		WINEDLLOVERRIDES=fusion=b "$WINE" /usr/share/wine-affinity/ndp48-x86-x64-allos-enu.exe /sfxlang:1027 /q /norestart || true
	fi
	rm -rf "$DOTNET48_TMP"
	"$WINESERVER" -k

	# vcrun2022 is installed from the baked-in 64-bit redist instead of
	# winetricks, because this WoW64 Wine build has no syswow64 (32-bit) path.
	echo "==> Installing VC++ 2022 redistributable..."
	"$WINE" /usr/share/wine-affinity/vc_redist.x64.exe /install /quiet /norestart
	"$WINESERVER" -k
	winecfg -v win11

	echo "==> Installing DLLs + WinRT metadata from the image..."
	/usr/libexec/affinity-sync-prefix

	for dll in d3d9 d3d10core d3d11 dxgi d3d12 d3d12core wintypes; do
		"$WINE" reg add 'HKCU\Software\Wine\DllOverrides' /v "$dll" /d native /f >/dev/null
	done

	echo ""
	echo "Download the Affinity v3 installer (.exe) from https://www.affinity.studio"
	exe=$(prompt "Path to the installer .exe:")
	WINEDEBUG=-all "$WINE" "$exe"

	appdir="$WINEPREFIX/drive_c/Program Files/Affinity/Affinity"
	if [[ -d "$appdir" ]]; then
		/usr/libexec/affinity-sync-prefix
		echo "Done. Launch from the Affinity menu entry, or run: affinity"
		echo "Verify OpenCL under Settings > Performance (Hardware acceleration)."
	else
		echo "Installer finished but $appdir was not found;"
		echo "re-run 'falcos affinity-setup' after a successful install."
		exit 1
	fi

# Remove this user's Affinity Wine prefix (the image-baked Wine and launcher remain)
[group('Apps')]
affinity-remove:
	#!/usr/bin/env bash
	set -eou pipefail
	/usr/lib/wine-affinity/bin/wineserver -k 2>/dev/null || true
	rm -rf "$HOME/.local/share/affinity"
	rm -f "$HOME/.local/share/applications/wine/Programs/Affinity.desktop"
	echo "Removed ~/.local/share/affinity"
