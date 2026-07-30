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
fetch_install_bin "$ASSET_AICHAT_URL" "$ASSET_AICHAT_SHA256" aichat

### Starship prompt
fetch_install_bin "$ASSET_STARSHIP_URL" "$ASSET_STARSHIP_SHA256" starship

### Flyline (Bash readline replacement)
fetch_extract "$ASSET_FLYLINE_URL" "$ASSET_FLYLINE_SHA256" /tmp/flyline
install -Dm755 "/tmp/flyline/libflyline.so.${ASSET_FLYLINE_VERSION}" /usr/lib/bash/libflyline.so
rm -rf /tmp/flyline

### Nerd Fonts
# The pin is of the release's SHA-256.txt manifest; each font archive is
# then verified against the manifest, so one pin covers all of them
fetch_verified "$ASSET_NERD_FONTS_URL" "$ASSET_NERD_FONTS_SHA256" /tmp/nerdfonts-sha.txt
# Which families to install is the image author's call, declared as the
# `fonts` option in module.kdl and arriving here resolved.
read -ra NERD_FONTS <<< "$OPT_FONTS"
for font in "${NERD_FONTS[@]}"; do
    # Each font sits beside the pinned manifest in the same release, so the
    # release URL is taken from the pin rather than written out a second
    # time where the two could drift apart.
    curl --retry 3 -fsSLo "/tmp/${font}.tar.xz" \
        "${ASSET_NERD_FONTS_URL%/*}/${font}.tar.xz"
    (cd /tmp && grep " ${font}\.tar\.xz$" nerdfonts-sha.txt | sha256sum -c -)
    mkdir -p "/usr/share/fonts/nerd-fonts/${font}"
    tar -xJf "/tmp/${font}.tar.xz" -C "/usr/share/fonts/nerd-fonts/${font}"
    rm "/tmp/${font}.tar.xz"
done
rm /tmp/nerdfonts-sha.txt
fc-cache -f
