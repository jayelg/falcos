# kde-desktop:latest

KDE Plasma Desktop environment with selected KDE applications.

**Packages installed:**
- kde-desktop group, networkmanager-submodules group
- plasma-browser-integration, plymouth (spinner theme)
- gvfs, input-remapper, kamera, kate, kate-plugins, ksystemlog, plasma-firewall
- krunner-bazaar (from ublue-os COPR)

**Packages removed:**
- abrt, PackageKit, plasma-discover, sssd, kdump, exotic qemu-user-static arches, various NetworkManager plugins

The stock Fedora kernel builds its initramfs outside this image build, so the
module does not contribute a `dracut.modules` fragment. Plymouth remains
installed for the desktop session and boot experience.
