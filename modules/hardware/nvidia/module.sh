### nvidia: the host driver, built for the image kernel and MOK-signed.
#
# NVIDIA's CUDA repository, not the multimedia one: 615.71.09 is the
# release the virtio-nvgpu backend has an exact ABI and video-memory
# profile for, so the per-VM VRAM limit works and no RM control falls
# back to an older release's table.
#
# Kernel modules are built from the DKMS package's source for the image
# kernel, so the toolchain is a build-time cost the finished image does
# not carry.

source /ctx/lib/kernel-helpers.sh
source /ctx/lib/sign-helpers.sh

CUDA_REPO="cuda-fedora44-x86_64"
NVVER="615.71.09"

# The repo key is imported explicitly: dnf5 in a build layer has no one
# to answer its key prompt.
rpm --import https://developer.download.nvidia.com/compute/cuda/repos/fedora44/x86_64/73CD9B30.pub

# nvidia-kmod-common -- the udev rules, modprobe config and firmware --
# requires nvidia-kmod, and the repo's only provider is the DKMS package:
# a multi-gigabyte source tree plus dkms plus a compiler toolchain, none
# of which belongs in an image that builds its own modules from that
# source. The fileless stub beside this script -- same name, same EVR --
# satisfies the requirement, so the userspace resolves without it. Its
# spec travels in the stub's description.
dnf5 install -y "$MODDIR/nvidia-kmod-stub.rpm"
dnf5 --enablerepo="$CUDA_REPO" install -y --setopt=install_weak_deps=False \
	"nvidia-kmod-common-${NVVER}" \
	"nvidia-driver-common-${NVVER}" \
	"nvidia-driver-cuda-${NVVER}" \
	"nvidia-driver-libs-${NVVER}"

# nvidia-driver-libs is the graphics half of the userspace -- EGL, GLX,
# GLES, Vulkan, GBM -- which nvidia-driver-cuda (compute) alone does not
# bring. A container that renders (Wolf/gamescope) needs it.

# The GOW images (ghcr.io/games-on-whales/*) link the driver from
# /usr/nvidia, the layout NVIDIA's own .run installer produces, because
# they ship no NVIDIA userspace of their own. Rather than build the
# upstream nvidia-driver image at runtime -- which downloads the .run
# installer and must be rebuilt on every driver bump -- collect the
# libraries this image already has into that same layout, once, here.
#
# ldconfig picks them up because the GOW images carry /usr/nvidia/lib in
# /etc/ld.so.conf.d; nothing else about this tree is special.
GOW_LIB=/usr/lib64/nvidia-gow
install -d "$GOW_LIB/lib" "$GOW_LIB/lib/gbm" "$GOW_LIB/share/vulkan/icd.d" \
	"$GOW_LIB/share/glvnd/egl_vendor.d" "$GOW_LIB/share/egl/egl_external_platform.d"

# Every driver .so, by glob across the two packages' naming. The symlinks
# (.so.1 -> .so.<ver>) come along with their targets, so the sonames the
# loader resolves stay intact.
find /usr/lib64 -maxdepth 1 \( -type f -o -type l \) -name '*.so*' |
	while IFS= read -r so; do
		case "$(basename "$so")" in
			libcuda.so*|libcudadebugger.so*|libnvcuvid.so*|libnvoptix.so*| \
			libnvidia-*.so*|libEGL_nvidia.so*|libGLX_nvidia.so*| \
			libGLESv1_CM_nvidia.so*|libGLESv2_nvidia.so*)
				cp -a "$so" "$GOW_LIB/lib/" ;;
		esac
	done

# GBM backend and the loader config files, at the paths the GOW init
# script (30-nvidia.sh) reads them from. Guarded rather than `&&` chained:
# set -e would abort the layer on a test that legitimately fails.
if [ -e /usr/lib64/gbm/nvidia-drm_gbm.so ]; then
	cp -a /usr/lib64/gbm/nvidia-drm_gbm.so "$GOW_LIB/lib/gbm/"
fi
for f in /usr/share/vulkan/icd.d/nvidia_icd*.json; do
	[ -e "$f" ] || continue
	cp -a "$f" "$GOW_LIB/share/vulkan/icd.d/"
done
if [ -e /usr/share/glvnd/egl_vendor.d/10_nvidia.json ]; then
	cp -a /usr/share/glvnd/egl_vendor.d/10_nvidia.json "$GOW_LIB/share/glvnd/egl_vendor.d/"
fi
# The EGL external-platform shims (wayland, gbm) live in the GOW image,
# not here; copy them from the same package-named sources if present.
for f in /usr/share/egl/egl_external_platform.d/*nvidia*.json; do
	[ -e "$f" ] || continue
	cp -a "$f" "$GOW_LIB/share/egl/egl_external_platform.d/"
done

# The DLSS/Wine NGX payload the installer also stages.
if [ -d /usr/lib64/nvidia/wine ]; then
	install -d "$GOW_LIB/lib/nvidia/wine"
	cp -a /usr/lib64/nvidia/wine/. "$GOW_LIB/lib/nvidia/wine/"
fi

# Kernel modules: built from the DKMS package's source for the image
# kernel. uname inside a build container reports the build host's kernel,
# not the image's, so KERNEL_UNAME names the kernel explicitly -- which
# is also exactly how the package's own dkms.conf builds it.
#
# The devel tree is pinned to the *installed* kernel's version, not
# kernel-devel-matched: matched tracks the repositories' newest kernel,
# which moves ahead of the base image's within a day of a Fedora release
# (measured: matched pulled 7.2.10 and upgraded the kernel inside this
# layer, whose %post runs the rpm-ostree kernel-install hook -- dracut in
# a build container, "Invalid cross-device link" -- and removed the
# 7.2.9 trees KERNEL_UNAME was about to build against). The exact version
# lives on in updates-archive.
KVER="$(kver)"
dnf5 install -y "kernel-devel-${KVER}" gcc gcc-c++ make elfutils-libelf-devel cpio git
dnf5 --enablerepo="$CUDA_REPO" download --destdir=/tmp/nvsdk "kmod-nvidia-open-dkms-${NVVER}"
(
	cd /tmp/nvsdk || exit 1
	rpm2cpio ./*.rpm | cpio -idm --quiet
)
srcdir="$(find /tmp/nvsdk -maxdepth 4 -type d -name 'nvidia-*' | head -1)"
[ -n "$srcdir" ] || {
	echo "no driver source tree in the downloaded package" >&2
	exit 1
}

make -C "$srcdir" modules -j"$(nproc)" KERNEL_UNAME="$KVER"

install -d "/usr/lib/modules/${KVER}/extra/nvidia"
install -m 0644 "$srcdir"/kernel-open/*.ko "/usr/lib/modules/${KVER}/extra/nvidia/"
depmod -a "$KVER"
rm -rf /tmp/nvsdk

# The signing cert has to exist before sign-helpers.sh is asked whether
# signing is possible: its files/ overlay copy lands after this script
# runs, so it is installed from the module directory first, the same
# shape as the kernel module's install of the same file.
install -Dm644 "$MODDIR/files/usr/share/nvgpu/sb_cert.der" /usr/share/secureboot/sb_cert.der
if mok_signing_available; then
	while IFS= read -r ko; do
		[ -n "$(modinfo -F signer "$ko" 2>/dev/null)" ] && continue
		sign_kernel_module "$ko" "/usr/src/kernels/${KVER}/scripts/sign-file"
	done < <(find "/usr/lib/modules/${KVER}/extra" -name "nvidia*.ko*" 2>/dev/null)
else
	echo "No MOK key supplied: NVIDIA modules will be unsigned and will not load under Secure Boot."
fi

# The build toolchain goes back out. Safe now that nothing else depends
# on it: dkms never entered the image (the stub kept it out), and cpio
# deliberately stays -- it is a dracut dependency and removing it once
# uninstalled dracut, bootc and rpm-ostree in one cascade. The
# kmod-common package stays: it is where the udev rules, the modprobe
# config and the firmware live.
dnf5 remove -y --noautoremove kernel-devel gcc gcc-c++ make elfutils-libelf-devel
