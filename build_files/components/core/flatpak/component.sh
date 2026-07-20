### Flatpak
# First-boot default-app install and the daily system update are wired via
# this component's files/ overlay (services + preset). Ensure the flatpak
# client itself is present; the fedora-bootc base does not guarantee it.
dnf5 install -y flatpak
