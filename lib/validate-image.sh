#!/bin/bash
# In-image assertions that run after module finalize hooks in the
# Containerfile LINTING section. A failed check stops the image before
# it is published. Each check is independent: all failures are reported
# before the script exits non-zero.

set -euo pipefail

failures=0
fail() {
	echo "FAIL: $*" >&2
	failures=$((failures + 1))
}

# bootc configuration
echo "==> bootc install print-configuration"
if bootc install print-configuration >/dev/null; then
	echo "    ok"
else
	fail "bootc install print-configuration failed to parse"
fi

# initramfs
echo "==> initramfs"
kernel_pkg="$(cat /usr/lib/kernel-build/kernel-package 2>/dev/null || echo 'kernel-core')"
if kver="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' "$kernel_pkg" 2>/dev/null)"; then
	initramfs="/usr/lib/modules/${kver}/initramfs.img"
	if [ -f "$initramfs" ]; then
		echo "    ${initramfs} present"
	else
		fail "initramfs missing at ${initramfs}"
	fi
else
	fail "cannot determine kernel version from package ${kernel_pkg}"
fi

# /usr/lib/opt symlinks
echo "==> /usr/lib/opt symlinks"
tmpfiles="/usr/lib/tmpfiles.d/zz-opt-symlinks.conf"
if [ -f "$tmpfiles" ]; then
	# Type Path Mode User Group Age Argument: the symlink target is the
	# Argument, four fields past Path, and Age is what one short lands on.
	while read -r type path _ _ _ _ target; do
		case "$type" in
		L+ | L)
			target="${target//\\x20/ }"
			if [ ! -e "$target" ]; then
				fail "${path} -> ${target}: target does not exist"
			else
				echo "    ${path} -> ${target} ok"
			fi
			;;
		esac
	done <"$tmpfiles"
else
	echo "    (no /usr/lib/opt symlinks declared)"
fi

# contract files
# Every provides-file the base node and the enabled modules declare,
# resolved from the manifests on the host and passed in, so this script
# knows no paths of its own. The base image's own binaries are in here
# too: they used to be a hardcoded list of three right here, which was the
# last place a path was written down outside a manifest.
#
# A path declared build-only is already excluded: the module that writes
# it removes it again before the image is finished, so asserting it exists
# here would fail a correct build.
echo "==> contract files"
if [ -z "${CONTRACT_FILES:-}" ]; then
	echo "    (none declared)"
else
	# shellcheck disable=SC2086
	set -- $CONTRACT_FILES
	for path in "$@"; do
		if [ -e "$path" ]; then
			echo "    ${path} ok"
		else
			fail "${path}: the manifest declares it, the image does not have it"
		fi
	done
fi

# Enablement symlinks for a unit under a config root. WantedBy and
# RequiredBy land in <target>.wants/ and <target>.requires/ one level
# down, named after the unit. An [Install] Alias instead lands beside
# them at the root, named after the alias and pointing at the unit:
# plasmalogin.service declares `Alias=display-manager.service`, so
# enabling it writes display-manager.service and nothing named
# plasmalogin.service exists anywhere. So both ends are matched, the
# link's own name and what it resolves to. A mask is a link to /dev/null
# and is not enablement either way.
enablement_links() {
	local root="$1" unit="$2" link target
	[ -d "$root" ] || return 0
	while IFS= read -r link; do
		[ -n "$link" ] || continue
		target="$(readlink "$link")"
		[ "$target" = /dev/null ] && continue
		if [ "${link##*/}" = "$unit" ] || [ "${target##*/}" = "$unit" ]; then
			printf '%s\n' "$link"
		fi
	done < <(find "$root" -maxdepth 2 -type l 2>/dev/null || true)
}

# systemd unit verification
# Every unit referenced by a preset must exist as a file, and the preset
# must actually have been applied: 99-finalize.sh runs systemctl enable
# and disable, which write and remove symlinks under /etc/systemd/<scope>,
# so those symlinks are the evidence. Reading them off disk is what makes
# this an assertion about enablement rather than about a unit merely
# existing, and it needs no PID 1, which a container build has not got.
# System units also pass through systemd-analyze verify, and a failure
# there is fatal unless every line it printed is allowed for that unit.
# User units skip verify because --user needs a running user manager.
# Unit files are found with find because systemctl show requires a
# running PID 1.
#
# Each class below is a fact about where this runs or about packaging,
# never a defect in the unit. A missing .service or .target, and a command
# that is not executable, all still fail. Devices need no entry: verify
# synthesises them and says nothing.
#
# This is the only place a verify diagnostic is written down as a regex. A
# manifest names a class instead, because a regex in a manifest is a
# footgun: one careless `.*` silences the check and no reviewer catches
# it. The class names are also in tools/manifest/src/module.rs, which
# validates the declarations; scripts/lint.sh checks the two agree.
declare -A verify_class=(
	# A container build has no mounts and no swap, so a unit ordered
	# against one cannot resolve it here.
	[mount-not-found]='Failed to create .*: Unit [^ ]+\.(mount|swap) not found\.$'
	# Documentation= is checked by running man against it. Whether a man
	# page was packaged is a packaging decision that says nothing about
	# whether the unit starts, and vendor units name pages this image does
	# not carry: plasmalogin names two.
	[man-page-missing]="Command 'man [^']*' failed with code [0-9]+\$"
)

# What the enabled modules accept, as <class>|<unit> tokens resolved per
# target on the host and passed in the way CONTRACT_FILES is.
#
# Scoped to one unit rather than allowed image-wide, which is what these
# patterns used to be. An exception belongs to the module that ships the
# unit, so delisting that module takes the exception with it, and a flavor
# that never had the module never had the exception either. The blanket
# version silenced the same diagnostic on all twenty-five units, including
# ones where it would have been a real defect.
verify_classes_known="$(printf '%s ' "${!verify_class[@]}")"
verify_classes_known="${verify_classes_known% }"
for token in ${VERIFY_EXCEPTIONS:-}; do
	class="${token%%|*}"
	if [ -z "${verify_class[$class]+set}" ]; then
		fail "allow-verify \"${class}\": not a diagnostic class this image knows;" \
			"known: ${verify_classes_known}"
	fi
done

# Every pattern declared for one unit, as a single alternation. Empty when
# nothing was declared for it, which is the normal case: a unit with no
# exceptions has to come back clean.
verify_allowed_for() {
	local unit="$1" token class allowed=""
	for token in ${VERIFY_EXCEPTIONS:-}; do
		[ "${token#*|}" = "$unit" ] || continue
		class="${token%%|*}"
		[ -n "${verify_class[$class]+set}" ] || continue
		allowed="${allowed:+${allowed}|}${verify_class[$class]}"
	done
	printf '%s' "$allowed"
}

# Which known class a diagnostic line falls into, or nothing. What turns a
# failure into an actionable message: a line matching a class needs a
# declaration, and a line matching none is more likely a real defect,
# because benign noise is a closed set.
verify_classify() {
	local line="$1" class
	for class in "${!verify_class[@]}"; do
		if printf '%s\n' "$line" | grep -Eq "${verify_class[$class]}"; then
			printf '%s' "$class"
			return 0
		fi
	done
}
echo "==> systemd unit verification"
checked=0
for scope in system user; do
	unit_dirs="/usr/lib/systemd/${scope} /etc/systemd/${scope}"
	for preset in "/usr/lib/systemd/${scope}-preset/"45-module-*.preset; do
		[ -f "$preset" ] || continue
		echo "    ${preset}"
		while read -r verb unit; do
			case "$verb" in
			enable | disable) ;;
			*) continue ;;
			esac
			checked=$((checked + 1))

			# shellcheck disable=SC2086
			unit_file="$(find ${unit_dirs} -name "${unit}" -print -quit 2>/dev/null || true)"
			if [ -z "$unit_file" ] || [ ! -f "$unit_file" ]; then
				# disable on a missing unit is a no-op, not a config error
				if [ "$verb" = "enable" ]; then
					fail "${unit}: unit file not found in ${unit_dirs}"
				else
					echo "        ${unit} (not present, ${verb}d)"
				fi
				continue
			fi

			# systemctl enable and --global enable write here, and
			# systemctl disable removes what it wrote.
			config_root="/etc/systemd/${scope}"
			links="$(enablement_links "$config_root" "$unit")"
			if [ "$verb" = "enable" ] && [ -z "$links" ]; then
				fail "${unit}: preset enables it, but nothing under ${config_root} does"
			elif [ "$verb" = "disable" ] && [ -n "$links" ]; then
				fail "${unit}: preset disables it, but ${config_root} still enables it:" \
					"$(echo "$links" | tr '\n' ' ')"
			fi

			if [ "$scope" = "system" ] && [ "$verb" = "enable" ]; then
				if out="$(systemd-analyze verify --no-pager "$unit" 2>&1)"; then
					echo "        ${unit} enabled"
				elif [ -z "${out//[[:space:]]/}" ]; then
					fail "${unit}: systemd-analyze verify failed without saying why"
				else
					allowed="$(verify_allowed_for "$unit")"
					if [ -n "$allowed" ]; then
						unexpected="$(printf '%s\n' "$out" |
							grep -Ev "$allowed" |
							grep -Ev '^[[:space:]]*$' || true)"
					else
						unexpected="$(printf '%s\n' "$out" |
							grep -Ev '^[[:space:]]*$' || true)"
					fi
					if [ -n "$unexpected" ]; then
						fail "${unit}: systemd-analyze verify"
						while IFS= read -r line; do
							[ -n "$line" ] || continue
							echo "          ${line}" >&2
							# Naming the declaration to add is what the
							# rest of the repo already does: lint says to
							# stage the regenerated file, manifest.sh
							# prints install instructions when cargo is
							# missing, flavors.sh prints the valid targets.
							class="$(verify_classify "$line")"
							if [ -n "$class" ]; then
								echo "            this is the known class '${class}'. If it is expected here," >&2
								echo "            declare it in the module shipping ${preset##*/}:" >&2
								echo "              allow-verify \"${class}\" unit=\"${unit}\"" >&2
							fi
						done <<< "$unexpected"
					else
						echo "        ${unit} enabled (verify: declared exceptions only)"
					fi
				fi
			else
				echo "        ${unit} ${verb}d"
			fi
		done <"$preset"
	done
done

if [ "$checked" -eq 0 ]; then
	fail "no module preset files found"
fi

# summary
echo
if [ "$failures" -eq 0 ]; then
	echo "All validation checks passed."
else
	echo "${failures} validation check(s) failed." >&2
	exit 1
fi
