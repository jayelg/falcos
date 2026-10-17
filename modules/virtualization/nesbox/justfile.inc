# justfile.inc -- goojust recipes this module contributes.
#
# The logic lives in /usr/libexec/nvgpu-create-microvm, which takes the
# answers as arguments; this recipe is the menu's prompts.

# Create a nesbox microVM with virtio-nvgpu
[group('Virtualization')]
create-nvgpu-microvm:
	#!/usr/bin/env bash
	set -eou pipefail
	source /usr/share/goojust/goojust-helpers.sh

	name=$(prompt "VM name:")
	kernel=$(prompt "Guest vmlinux path:")
	rootfs=$(prompt "Guest rootfs path:")
	if [ -z "$name" ] || [ -z "$kernel" ] || [ -z "$rootfs" ]; then
		echo "a name, a kernel and a rootfs are all needed" >&2
		exit 1
	fi
	/usr/libexec/nvgpu-create-microvm "$name" "$kernel" "$rootfs"
