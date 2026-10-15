# justfile.inc -- goojust recipes this module contributes.
#
# The logic lives in /usr/libexec/nvgpu-create-vm and nvgpu-add-vm, which
# take the answers as arguments; these recipes are the menu's prompts.

# Create VM with virtio-nvgpu
[group('Virtualization')]
create-nvgpu-vm:
	#!/usr/bin/env bash
	set -eou pipefail
	source /usr/share/goojust/goojust-helpers.sh

	name=$(prompt "VM name:")
	iso=$(prompt "Installer ISO path:")
	[ -n "$name" ] && [ -n "$iso" ] || { echo "a name and an ISO path are both needed" >&2; exit 1; }
	/usr/libexec/nvgpu-create-vm "$name" "$iso"

# Add virtio-nvgpu to VM
[group('Virtualization')]
add-nvgpu-vm:
	#!/usr/bin/env bash
	set -eou pipefail
	source /usr/share/goojust/goojust-helpers.sh

	name=$(prompt "VM name:")
	[ -n "$name" ] || { echo "a VM name is needed" >&2; exit 1; }
	/usr/libexec/nvgpu-add-vm "$name"
