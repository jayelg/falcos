# CLI customizations — opinionated shell UX: modern replacements for the
# default tools (aliased over cat/ls/grep/cd in files/etc/profile.d/zz-bling.sh),
# a fancier prompt/readline, an AI CLI, and Nerd Fonts. Distinct from
# cli-tools, which stays traditional utilities only.

### Modern CLI tooling (dnf)
CUSTOMIZATION_PACKAGES=(
    bat        # cat
    eza        # ls
    fd-find    # find
    gum        # TUI scripting helper
    ripgrep    # grep (additive: rg)
    ugrep      # grep (aliased)
    zoxide     # cd
)
dnf5 install -y "${CUSTOMIZATION_PACKAGES[@]}"

source /ctx/lib/fetch-helpers.sh

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
