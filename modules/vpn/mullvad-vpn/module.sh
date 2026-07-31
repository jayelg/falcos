# Mullvad VPN daemon
# Installed here rather than declared: the package comes from the repo
# the sibling `repo` file adds, and that runs after a declared install
# would have.
dnf5 install -y mullvad-vpn
