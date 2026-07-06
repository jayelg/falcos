### VPN clients
# Mullvad, Netbird, and Tailscale all ship their own releases far more
# often than typical Fedora-repo packages — kept out of common/core/100-networking.sh
# so those release cadences don't force a rebuild of the rest of that layer.
dnf5 install -y mullvad-vpn netbird
dnf5 install -y --enablerepo='tailscale-stable' tailscale
