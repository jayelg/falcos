### VSCodium
dnf5 install -y --enablerepo='vscodium' codium

# Electron crashes under the system-wide hardened_malloc LD_PRELOAD, wrap
# the binary to drop it
source /ctx/lib/wrap-helpers.sh
wrap_no_hardened_malloc /usr/share/codium/codium

### Bitwarden CLI
curl -fsSL "https://github.com/bitwarden/clients/releases/download/cli-v${BW_VERSION}/bw-linux-${BW_VERSION}.zip" \
    -o /tmp/bw.zip
echo "${BW_SHA256}  /tmp/bw.zip" | sha256sum -c -
unzip /tmp/bw.zip -d /tmp/bw-extract
install -m755 /tmp/bw-extract/bw /usr/bin/bw
rm -rf /tmp/bw.zip /tmp/bw-extract

### aichat CLI
curl -fsSL "https://github.com/sigoden/aichat/releases/download/v${AICHAT_VERSION}/aichat-v${AICHAT_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    -o /tmp/aichat.tar.gz
tar -xzf /tmp/aichat.tar.gz -C /tmp/
install -m755 /tmp/aichat /usr/bin/aichat
rm -rf /tmp/aichat.tar.gz /tmp/aichat

### Starship prompt
curl -fsSL "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-x86_64-unknown-linux-musl.tar.gz" \
    -o /tmp/starship.tar.gz
tar -xzf /tmp/starship.tar.gz -C /tmp/
install -m755 /tmp/starship /usr/bin/starship
rm -rf /tmp/starship.tar.gz /tmp/starship

### Nerd Fonts
NERD_FONTS=(0xProto CascadiaMono ComicShannsMono DroidSansMono FiraCode Go-Mono IBMPlexMono JetBrainsMono SourceCodePro Ubuntu)
for font in "${NERD_FONTS[@]}"; do
    curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONTS_VERSION}/${font}.tar.xz" \
        -o /tmp/nerdfont.tar.xz
    mkdir -p "/usr/share/fonts/nerd-fonts/${font}"
    tar -xJf /tmp/nerdfont.tar.xz -C "/usr/share/fonts/nerd-fonts/${font}"
    rm /tmp/nerdfont.tar.xz
done
fc-cache -f
