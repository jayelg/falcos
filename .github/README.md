# Falcos

Falcos is a self-managed atomic desktop Linux image. It is based on a minimal fedora-bootc image so that the majority of software and configuration is managed in this repo. It uses Github Actions and Renovate to automate image updates when upstream updates become available.

## Repo Structure

### [Containerfile](Containerfile)

The containerfile defines the build: 
- The base image
- Seperate build phases - So that phases can be cached and more frequent updates do not cause a full image rebuild.
- Build scripts (`*.sh` in the [`build_files`](build_files) directory) loaded in order for each phase.
-  Bootc linting the final image at the end of the build.

### [Build Files Directory](build_files)

Everything that runs at build time, the phase scripts, the package install scripts and the static directories and files copied into the image.

### [Github Actions](.github)

CI workflows that build, sign and publish the images, plus a Renovate automation for dependency updates.

### [Dev Scripts](Justfile)

The justfile contains scripts for building and testing outside of CI 

## Features
Base image: Fedora-Bootc
Kernel: CachyOS-Kernel
Desktop Environment: KDE-Plasma-Desktop
Package managers: Flatpak, Homebrew

## Build Flavours
This image distributes 2 personal variants:
- falcos-desktop - with tweaks for my desktop hardware
- falcos-laptop - with tweaks for my Framework 13 Laptop hardware

## References

It was based on the ublue/image-template and has followed a similar implementation to Universal Blue's Aurora and Bazzite images as well as some hardening and software from SecureBlue.

## Notes / Todo
