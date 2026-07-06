# dnf5-command(config-manager) — not in fedora-bootc by default, unlike Kinoite
dnf5 install -y dnf5-plugins

### Add repos

# Mullvad VPN
dnf5 config-manager addrepo --from-repofile=https://repository.mullvad.net/rpm/stable/mullvad.repo

# Netbird
cat <<EOF > /etc/yum.repos.d/netbird.repo
[netbird]
name=netbird
baseurl=https://pkgs.netbird.io/yum/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.netbird.io/yum/repodata/repomd.xml.key
repo_gpgcheck=1
EOF

# negativo17 multimedia
dnf5 config-manager addrepo --from-repofile="https://negativo17.org/repos/fedora-multimedia.repo"
dnf5 config-manager setopt fedora-multimedia.priority=90

# Tailscale
dnf5 config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
dnf5 config-manager setopt tailscale-stable.enabled=0

# VSCodium
dnf5 config-manager addrepo --from-repofile=https://repo.vscodium.dev/vscodium.repo
dnf5 config-manager setopt vscodium.enabled=0

# secureblue (Trivalent browser)
dnf5 config-manager addrepo --from-repofile=https://repo.secureblue.dev/secureblue.repo
dnf5 config-manager setopt secureblue.enabled=0
