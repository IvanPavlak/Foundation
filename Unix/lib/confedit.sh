# shellcheck shell=bash
# Writers for the Unix config files - the shared core of the Configuration module (Add-Workspace,
# Add-Project, Add-BrowserGroup). They write to the NAME.local.conf overlay, never to the base
# file a generic repository ships, as Initialize-Configuration and the app-list overlays do on
# Windows. Every write to an existing overlay backs it up into the sink first
# (Backups/Unix/Config/<file>/<timestamp>/) and does not happen when that fails. Needs
# lib/config.sh and lib/backup.sh.

# Key of a config file in the backup sink: its path under Unix/config (layouts/Work.conf =>
# layouts.Work), or its file name.
conf__backup_key() {
	local rel=${1#"$FOUNDATION_CONFIG_DIR"/}
	rel=${rel%.conf}
	printf '%s' "${rel//\//.}"
}

# Appends [NAME] with the lines read from stdin to the .local.conf overlay of FILE, creating the
# overlay with a header when it is missing. Fails - writing nothing - when FILE is missing, the
# section already exists (in the file or its overlay) or the backup cannot be taken.
# Usage: conf_add_section FILE NAME <<<"lines"
conf_add_section() {
	local file=$1 name=$2 existing lines target
	[ -f "$file" ] || {
		log_error "Missing ${file#"$DOTFILES_ROOT"/}"
		return 1
	}
	case $name in '' | *[][]*)
		log_error "Invalid section name [$name]"
		return 1
		;;
	esac
	target=$(conf__local_path "$file")
	if existing=$(conf_section_name "$file" "$name"); then
		local where=$file
		[ -f "$target" ] && conf__section_raw "$target" "$name" >/dev/null && where=$target
		log_error "[$existing] already exists in ${where#"$DOTFILES_ROOT"/} - edit it there"
		return 1
	fi
	lines=$(cat)
	if [ -f "$target" ]; then
		backup_item Config "$(conf__backup_key "$target")" "$target" >/dev/null || return 1
		# One blank line between sections, whatever the file ended with.
		[ -z "$(tail -c 1 "$target")" ] || printf '\n' >>"$target"
	else
		printf '# Overlay of %s: its sections replace same-named sections there and add new ones\n# (docs/unix/configuration.md).\n' "${file##*/}" >"$target" || return 1
	fi
	{
		printf '\n[%s]\n' "$name"
		[ -n "$lines" ] && printf '%s\n' "$lines"
	} >>"$target"
	log_success "Added [$name] to ${target#"$DOTFILES_ROOT"/}"
}

# Sets the top-level `KEY VALUE` line (the part before the first section) in the .local.conf
# overlay of FILE: an overlay line of KEY is replaced in place, else the line goes in before the
# overlay's first section (or at its end), so it wins over the base file's line as conf_value
# reads the last match. Creates the overlay with a header when it is missing. Fails - writing
# nothing - when FILE is missing or the backup cannot be taken.
# Usage: conf_set_value FILE KEY VALUE
conf_set_value() {
	local file=$1 key=$2 value=$3 target tmp
	[ -f "$file" ] || {
		log_error "Missing ${file#"$DOTFILES_ROOT"/}"
		return 1
	}
	target=$(conf__local_path "$file")
	if [ -f "$target" ]; then
		backup_item Config "$(conf__backup_key "$target")" "$target" >/dev/null || return 1
	else
		printf '# Overlay of %s: its sections replace same-named sections there and add new ones\n# (docs/unix/configuration.md).\n' "${file##*/}" >"$target" || return 1
	fi
	tmp=$(mktemp) || return 1
	# Blank lines are held back until the next line, so a new line lands right after the last
	# top-level one, never after the blank lines that set off the first section.
	if ! awk -v k="$(foundation_lower "$key")" -v line="$key $value" '
		function flush() { printf "%s", pending; pending = "" }
		sectioned { print; next }
		/^[[:space:]]*\[/ {
			if (!done) { print line; done = 1; if (pending == "") pending = "\n" }
			flush(); sectioned = 1; print; next
		}
		/^[[:space:]]*$/ { pending = pending $0 "\n"; next }
		{ split($0, w, " "); if (tolower(w[1]) == k) { flush(); if (!done) { print line; done = 1 } next } }
		{ flush(); print }
		END { if (!sectioned) { if (!done) print line; flush() } }' "$target" >"$tmp" || ! cat "$tmp" >"$target"; then
		rm -f "$tmp"
		log_error "Could not write [$key] to ${target#"$DOTFILES_ROOT"/}"
		return 1
	fi
	rm -f "$tmp"
	log_success "Set [$key $value] in ${target#"$DOTFILES_ROOT"/}"
}
