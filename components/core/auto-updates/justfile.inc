# Update system and flatpaks
[group('System')]
update:
	#!/usr/bin/bash
	source /usr/share/falcos/falcos-helpers.sh
	SERVICE="bootc-fetch-apply-updates.service"
	if systemctl is-active --quiet "$SERVICE"; then
		echo "Automatic updates are currently running, use \`journalctl -fexu $SERVICE\` to see logs"
		exit 1
	fi
	echo "==> Updating system image..."
	prog 10
	if command -v rpm-ostree >/dev/null 2>&1 && [ -f /etc/rpm-ostreed.conf ] && \
		grep -qE '^[[:space:]]*LockLayering[[:space:]]*=[[:space:]]*true' /etc/rpm-ostreed.conf; then
		sudo bootc upgrade
	else
		rpm-ostree upgrade
	fi
	echo "==> Updating flatpaks..."
	prog 60
	if flatpak remotes | grep -q system; then
		flatpak update -y
	fi
	if flatpak remotes | grep -q user; then
		flatpak update --user -y
	fi
	prog 100
	prog clear
	echo "Done."
