# shellcheck shell=bash
# Package pins (config/package-pins.conf) - the Sync-AppPins core of Windows: makes a package
# manager's own pins match the configured list, in both directions, before Upgrade-All upgrades.
#
# Only Homebrew can pin today (mas and softwareupdate cannot), so pins_sync knows that one manager;
# a manager that joins gets a `pins__sync_<manager>` of its own and a line kind in the file.

# The packages pinned for MANAGER on this machine, one per line: the second field of every
# `MANAGER NAME` line (the manager compares case-insensitively). Nothing without the file.
# Usage: pins_wanted brew
pins_wanted() {
	local file kind name _
	file=$(conf_path package-pins.conf) || return 0
	while read -r kind name _; do
		[ "$(foundation_lower "$kind")" = "$(foundation_lower "$1")" ] && [ -n "$name" ] && printf '%s\n' "$name"
	done < <(conf_lines "$file")
	return 0
}

# Reconciles MANAGER's pins with package-pins.conf and lists what stays pinned. Fails when the
# pin state cannot be read or a pin or unpin fails: the caller must not upgrade then, since a
# pin that never landed would let the upgrade move a package it should keep.
# Usage: pins_sync Homebrew
pins_sync() {
	case $(foundation_lower "$1") in
		homebrew | brew) pins__sync_homebrew ;;
		*) return 0 ;;
	esac
}

# The Brewfiles Bootstrap bundles: the `brewfile` lines of bootstrap.conf [Packages] (relative to
# the repository root), else Unix/Brewfile and Unix/Brewfile.local. One path per line.
pins__brewfiles() {
	local file line kind rest found=''
	if file=$(conf_path bootstrap.conf); then
		while read -r kind rest; do
			[ "$kind" = brewfile ] && [ -n "$rest" ] || continue
			case $rest in /*) ;; *) rest=$DOTFILES_ROOT/$rest ;; esac
			printf '%s\n' "$rest"
			found=1
		done < <(conf_section "$file" Packages 2>/dev/null || true)
	fi
	[ -n "$found" ] || printf '%s\n%s\n' "$FOUNDATION_UNIX/Brewfile" "$FOUNDATION_UNIX/Brewfile.local"
}

# The formulae the bundled Brewfiles name, one per line, as `brew list` names them (a tap
# formula `user/tap/name` is `name`): the formulae Foundation manages, the only ones whose pin it
# may remove.
pins__brew_managed() {
	local brewfile
	while IFS= read -r brewfile; do
		[ -r "$brewfile" ] || continue
		sed -n 's/^[[:space:]]*brew[[:space:]][[:space:]]*"\([^"]*\)".*/\1/p' "$brewfile"
	done < <(pins__brewfiles) | sed 's#.*/##'
}

pins__sync_homebrew() {
	local wanted pinned managed installed='' name failed=0 changed=''
	wanted=$(pins_wanted brew)
	if ! pinned=$(brew list --pinned); then
		log_error "Could not read the pinned Homebrew formulae (brew list --pinned)"
		return 1
	fi

	# A pin outlives the decision behind it unless it is taken back: a managed formula still
	# pinned without a line is unpinned. A pin on a formula no Brewfile names stays.
	if [ -n "$pinned" ]; then
		managed=$(pins__brew_managed)
		while IFS= read -r name; do
			[ -n "$name" ] || continue
			printf '%s\n' "$wanted" | grep -qxF "$name" && continue
			printf '%s\n' "$managed" | grep -qxF "$name" || continue
			log_warning "Removing stale pin for [$name] - it is no longer version-pinned"
			brew unpin "$name" || failed=1
			changed=1
		done <<<"$pinned"
	fi

	while IFS= read -r name; do
		[ -n "$name" ] || continue
		printf '%s\n' "$pinned" | grep -qxF "$name" && continue
		# brew pin refuses a formula that is not installed, so the installed list is read once,
		# only when there is something to pin.
		if [ -z "$installed" ] && ! installed=$(brew list --formula -1); then
			log_error "Could not read the installed Homebrew formulae (brew list --formula)"
			return 1
		fi
		if ! printf '%s\n' "$installed" | grep -qxF "$name"; then
			log_warning "[$name] is version-pinned but not installed - the next Upgrade-All after it is installed pins it"
			continue
		fi
		brew pin "$name" || failed=1
		changed=1
	done <<<"$wanted"

	if [ -n "$changed" ] && ! pinned=$(brew list --pinned); then
		log_error "Could not read the pinned Homebrew formulae (brew list --pinned)"
		return 1
	fi
	if [ -n "$pinned" ]; then
		log_warning "Skipping version-pinned packages"
		printf '%s\n' "$pinned" | sed 's/^/  - /'
	fi
	return "$failed"
}
