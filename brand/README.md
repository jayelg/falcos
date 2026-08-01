[root](../README.md) / **brand**

The image's own assets, declared in [image.kdl](../image.kdl) and installed by [50-flavor.sh](../build-phases/50-flavor.sh). Nothing here belongs to a module: a module is a reusable build unit and this is the identity of one image, so it lives beside the declaration that names it rather than in a `files/` overlay.

The build context carries this directory for the phases below the module layers, which is why a declared path has to be in it.

### [Distributor Logo](distributor-logo-symbolic.svg)

The scalable icon the desktop shows for the OS. Installed into the hicolor theme under its own filename, and the filename without its extension is what os-release `LOGO` is set to, so the two cannot drift.

### [Plymouth Watermark](watermark.png)

The boot splash watermark, installed into the spinner theme.
