### ublue-os/packages COPR — krunner-bazaar
# Repo disabled immediately after enabling; install is scoped to its repo ID
# so nothing else can shadow the package.
dnf5 -y copr enable ublue-os/packages
dnf5 -y copr disable ublue-os/packages
dnf5 -y install --enablerepo="copr:copr.fedorainfracloud.org:ublue-os:packages" \
    krunner-bazaar
