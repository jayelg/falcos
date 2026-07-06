### Networking
# VPN clients (Mullvad, Netbird, Tailscale) live in
# common/frequent/010-vpn.sh — they release far more often than these
# genuinely stable networking utilities.
NETWORK_PACKAGES=(
    avahi-gobject      # GObject bindings for Avahi (mDNS/Zeroconf discovery)
    avahi-tools        # avahi-browse/avahi-resolve CLI tools
    cifs-utils         # mount SMB/CIFS network shares
    nmap-ncat
    tcpdump
    traceroute
    wireguard-tools
)
dnf5 install -y "${NETWORK_PACKAGES[@]}"
