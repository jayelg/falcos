# Pinned CLI Tools (metapackage: VSCodium, Bitwarden CLI, aichat, Starship, Flyline, falcos-cli, Nerd Fonts)
# Writable paths: /usr/bin /usr/share/codium /usr/share/fonts /usr/lib/bash

source /ctx/lib/fetch-helpers.sh

### VSCodium
dnf5 install -y --enablerepo='vscodium' codium

# Electron crashes under the system-wide hardened_malloc LD_PRELOAD, wrap
# the binary to drop it
source /ctx/lib/wrap-helpers.sh
wrap_no_hardened_malloc /usr/share/codium/codium

### Bitwarden CLI
fetch_install_bin "https://github.com/bitwarden/clients/releases/download/cli-v${BW_VERSION}/bw-linux-${BW_VERSION}.zip" \
    "$BW_SHA256" bw

### aichat CLI
fetch_install_bin "https://github.com/sigoden/aichat/releases/download/v${AICHAT_VERSION}/aichat-v${AICHAT_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    "$AICHAT_SHA256" aichat

### Starship prompt
fetch_install_bin "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-x86_64-unknown-linux-musl.tar.gz" \
    "$STARSHIP_SHA256" starship

### Flyline (Bash readline replacement)
fetch_extract "https://github.com/HalFrgrd/flyline/releases/download/v${FLYLINE_VERSION}/libflyline-v${FLYLINE_VERSION}-x86_64-unknown-linux-gnu.tar.gz" \
    "$FLYLINE_SHA256" /tmp/flyline
install -Dm755 "/tmp/flyline/libflyline.so.${FLYLINE_VERSION}" /usr/lib/bash/libflyline.so
rm -rf /tmp/flyline

### falcos-cli (OS TUI, aliased to the OS name via etc/profile.d/falcos-cli.sh)
### Includes runtime helper scripts: falcos-helpers.sh, falcos-progress
fetch_extract "https://github.com/jayelg/falcos-cli/releases/download/v${FALCOS_CLI_VERSION}/falcos-cli-v${FALCOS_CLI_VERSION}-x86_64-linux-gnu.tar.gz" \
    "$FALCOS_CLI_SHA256" /tmp
bash /tmp/install.sh
rm -rf /tmp/falcos-cli /tmp/install.sh /tmp/scripts/

### Nerd Fonts
# The pin is of the release's SHA-256.txt manifest; each font archive is
# then verified against the manifest, so one pin covers all of them
fetch_verified "https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONTS_VERSION}/SHA-256.txt" \
    "$NERD_FONTS_SHA256" /tmp/nerdfonts-sha.txt
NERD_FONTS=(0xProto CascadiaMono ComicShannsMono DroidSansMono FiraCode Go-Mono IBMPlexMono JetBrainsMono SourceCodePro Ubuntu)
for font in "${NERD_FONTS[@]}"; do
    curl --retry 3 -fsSLo "/tmp/${font}.tar.xz" \
        "https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONTS_VERSION}/${font}.tar.xz"
    (cd /tmp && grep " ${font}\.tar\.xz$" nerdfonts-sha.txt | sha256sum -c -)
    mkdir -p "/usr/share/fonts/nerd-fonts/${font}"
    tar -xJf "/tmp/${font}.tar.xz" -C "/usr/share/fonts/nerd-fonts/${font}"
    rm "/tmp/${font}.tar.xz"
done
rm /tmp/nerdfonts-sha.txt
fc-cache -f
