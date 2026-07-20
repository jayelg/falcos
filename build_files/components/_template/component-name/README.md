# component-name

<!-- One or two sentences: what this component adds to the image and why.
     Match the tone of the existing component READMEs (see ../../core/brew or
     ../../apps/vscodium). Rename the heading to the component name. -->

## Build

<!-- What component.sh does at build time: packages installed, assets fetched
     (with checksum verification), any wrapping/SELinux/DKMS steps. Omit this
     section for a pure-file component. -->

## Files

<!-- List what the files/ overlay ships and what each piece is for, e.g. the
     45-falcos-<name>.preset and any config/service/libexec. Omit if none. -->

## Flatpaks

<!-- If this component ships default flatpaks for first-boot install, list
     them in a flatpaks.list file (one ID per line). Omit the file if none.
     At build time run-component.sh concatenates every component's
     flatpaks.list into /usr/share/falcos/default-flatpaks; the flatpak
     component's install-flatpaks service installs each one on
     first boot. -->

## Runtime

<!-- Optional: anything a user should know about how it behaves on the running
     system (first-boot services, recipes it adds, manual steps). -->
