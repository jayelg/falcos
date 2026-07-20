# Set up dotfiles and secrets with chezmoi and Vaultwarden — run once on a new machine
[group('Configuration')]
setup-dotfiles:
	#!/usr/bin/env bash
	set -eou pipefail
	source /usr/share/falcos/falcos-helpers.sh

	# ── Phase 1: Check status, collect only what's needed ────
	echo "==> Checking Bitwarden status..."
	BW_STATUS=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unauthenticated")
	if [[ "$BW_STATUS" == "unauthenticated" ]]; then
		BW_SERVER=$(prompt "Vaultwarden URL:")
		BW_EMAIL=$(prompt "Bitwarden email:")
	fi

	if [[ "$BW_STATUS" != "unlocked" ]]; then
		BW_PASSWORD=$(prompt "Bitwarden master password:" true)
		export BW_PASSWORD
	fi

	# ── Phase 2: Execute auth operations ──────────────────────
	echo "==> Configuring Bitwarden CLI..."
	if [[ -n "${BW_SERVER:-}" ]]; then
		bw config server "$BW_SERVER"
	fi

	echo "==> Authenticating Bitwarden vault..."
	if [[ "$BW_STATUS" == "unauthenticated" ]]; then
		BW_SESSION=$(bw login "$BW_EMAIL" --passwordenv BW_PASSWORD --raw)
	elif [[ "$BW_STATUS" == "locked" ]]; then
		BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)
	fi

	unset BW_PASSWORD
	export BW_SESSION

	# ── Phase 3: Remaining setup (SSH, chezmoi) ──────────────
	echo ""
	echo "==> Checking SSH key for GitHub..."
	SSH_KEY="${HOME}/.ssh/id_ed25519_github"
	if [[ ! -f "$SSH_KEY" ]]; then
		echo "No SSH key found. Generating one..."
		ssh-keygen -t ed25519 -C "$(hostname)-$(git config user.email 2>/dev/null || echo '')" -N "" -f "$SSH_KEY"
	fi

	SSH_CONFIG="${HOME}/.ssh/config"
	mkdir -p "${HOME}/.ssh"
	touch "$SSH_CONFIG"
	chmod 600 "$SSH_CONFIG"
	if ! grep -qF "IdentityFile ${SSH_KEY}" "$SSH_CONFIG"; then
		printf '\nHost github.com\n    IdentityFile %s\n    IdentitiesOnly yes\n' "$SSH_KEY" >> "$SSH_CONFIG"
	fi

	export GIT_SSH_COMMAND="ssh -i ${SSH_KEY} -o IdentitiesOnly=yes"

	SSH_RESULT=$(ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5 -T git@github.com 2>&1 || true)
	if ! echo "$SSH_RESULT" | grep -q "successfully authenticated"; then
		echo ""
		echo "SSH key is not yet registered on GitHub. Add this public key at:"
		echo "  https://github.com/settings/ssh/new"
		echo ""
		cat "${SSH_KEY}.pub"
		echo ""
		read -rp "Press Enter once you've added the key to GitHub..."

		SSH_RESULT=$(ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5 -T git@github.com 2>&1 || true)
		if ! echo "$SSH_RESULT" | grep -q "successfully authenticated"; then
			echo "Error: SSH authentication to GitHub still failing. Check that the key was added correctly."
			exit 1
		fi
	fi
	echo "GitHub SSH authentication confirmed."

	echo ""
	echo "==> Applying dotfiles..."
	chezmoi init --apply git@github.com:johngrantdev/dotfiles.git

	echo ""
	echo "Done! Dotfiles applied."
	echo "To keep the vault unlocked in your current shell, run:"
	echo "  export BW_SESSION=\$(bw unlock --raw)"
