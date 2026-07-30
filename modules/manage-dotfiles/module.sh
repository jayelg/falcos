# manage-dotfiles — new-machine user setup: dotfiles (chezmoi) + secrets
# (Bitwarden CLI against a Vaultwarden server). Ships the `setup-dotfiles`
# recipe as justfile.inc; jq parses `bw status` inside it.

### chezmoi (dotfiles) + jq (parses bw status in setup-dotfiles)
dnf5 install -y chezmoi jq

### Bitwarden CLI
source /ctx/lib/fetch-helpers.sh
fetch_install_bin "$ASSET_BW_URL" "$ASSET_BW_SHA256" bw
