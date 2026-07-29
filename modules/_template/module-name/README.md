# module-name

<!-- One or two sentences: what this module adds to the image and why.
     Match the tone of the existing module READMEs (see ../../core/brew or
     ../../apps/vscodium). Rename the heading to the module name. -->

## Build

<!-- What module.sh does at build time: packages installed, assets fetched
     (with checksum verification), any wrapping/SELinux/DKMS steps. Omit this
     section for a pure-file module. -->

## Files

<!-- List what the files/ overlay ships and what each piece is for, e.g. the
     45-falcos-<name>.preset and any config/service/libexec. Omit if none. -->

## Flatpaks

<!-- If this module ships default flatpaks for first-boot install, list
     them in a flatpaks.list file (one ID per line). Omit the file if none.
     At build time run-module.sh concatenates every module's
     flatpaks.list into /usr/share/falcos/default-flatpaks; the flatpak
     module's install-flatpaks service installs each one on
     first boot. -->

## Runtime

<!-- Optional: anything a user should know about how it behaves on the running
     system (first-boot services, recipes it adds, manual steps). -->
