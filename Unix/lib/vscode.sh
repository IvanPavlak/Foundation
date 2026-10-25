# shellcheck shell=bash
# VS Code profiles - the Resolve-VSCodeProfilesConfig, Get-VSCodeCliPath, Get-VSCodeProfileLocation,
# Get-VSCodeProfileItems, Get-VSCodeInstalledExtensions, ConvertFrom-VSCodeExtensionLine,
# Merge-VSCodeExtensionList and Get-VSCodeLocalExtensions family of Windows, shared by
# Deploy-VSCodeProfiles and Export-VSCodeProfile. Reads Unix/config/vscode-profiles.conf. Needs
# lib/config.sh and lib/backup.sh; editing VS Code's profile list and reading local extensions
# need jq.

# vscode-profiles.conf value KEY for this machine type, or DEFAULT when the file or key is missing
# or the value is empty.
vscode_setting() { # KEY DEFAULT
	local file value
	file=$(conf_path vscode-profiles.conf) && value=$(conf_value "$file" "$1") && [ -n "$value" ] && {
		printf '%s' "$value"
		return 0
	}
	printf '%s' "$2"
}

# Succeeds when the on|off setting KEY is on (default off).
vscode_flag() { # KEY
	[ "$(foundation_lower "$(vscode_setting "$1" off)")" = on ]
}

# The profile folders in the repository, one subfolder per catalogue entry.
vscode_root() {
	foundation_expand_path "$(vscode_setting root '$DOTFILES_ROOT/VSCode/Profiles')"
}

# The repository's local extensions: one unpackaged extension folder (with a package.json) each,
# such as a colour theme of your own.
vscode_local_root() {
	foundation_expand_path "$(vscode_setting extensions '$DOTFILES_ROOT/VSCode/Extensions')"
}

# VS Code's extensions folder, where every extension lives as <id>-<version>.
vscode_extensions_dir() {
	printf '%s' "$HOME/.vscode/extensions"
}

# Get-VSCodeLocalExtensions: the local extensions under ROOT as ID<TAB>VERSION<TAB>LINK-NAME<TAB>SOURCE
# lines, sorted by folder name. ID is <publisher>.<name> lowercased, LINK-NAME is <ID>-<VERSION>,
# the folder name VS Code expects. A folder without a package.json is ignored; one that is not
# valid JSON or lacks publisher, name or version is skipped with a warning. A missing ROOT lists
# nothing. Needs jq. The warnings go to stderr: stdout carries the lines.
# Usage: vscode_local_extensions ROOT
vscode_local_extensions() {
	local root=$1 dir manifest fields publisher name id version
	[ -d "$root" ] || {
		log_debug "No local VS Code extensions folder [$root]" >&2
		return 0
	}
	command -v jq >/dev/null 2>&1 || {
		log_warning "jq is needed to read the local VS Code extensions - brew install jq" >&2
		return 0
	}
	for dir in "$root"/*/; do
		dir=${dir%/}
		manifest=$dir/package.json
		[ -f "$manifest" ] || continue
		if ! jq empty "$manifest" >/dev/null 2>&1; then
			log_warning "[$manifest] is not valid JSON - local extension [${dir##*/}] skipped!" >&2
			continue
		fi
		fields=$(jq -r '[.publisher, .name, .version] | map(if type == "string" then . else "" end) | join("\t")' "$manifest")
		IFS=$'\t' read -r publisher name version <<<"$fields"
		if [ -z "$publisher" ] || [ -z "$name" ] || [ -z "$version" ]; then
			log_warning "[$manifest] needs publisher, name and version - local extension [${dir##*/}] skipped!" >&2
			continue
		fi
		id=$(foundation_lower "$publisher.$name")
		printf '%s\t%s\t%s\t%s\n' "$id" "$version" "$id-$version" "$dir"
	done
}

# VS Code's user data folder: its root is the Default profile, other profiles live under
# profiles/<location>.
vscode_user_data() {
	local fallback='$HOME/Library/Application Support/Code/User'
	[ "$(uname -s)" = Darwin ] || fallback='$HOME/.config/Code/User'
	foundation_expand_path "$(vscode_setting user-data "$fallback")"
}

# The catalogue as NAME<TAB>TARGET lines, in the order the names first appear; a later `profile`
# line for the same name (the local overlay) changes its target. TARGET defaults to NAME.
vscode_catalogue() {
	local file
	file=$(conf_path vscode-profiles.conf) || return 0
	conf_lines "$file" | awk '
		tolower($1) == "profile" && NF >= 2 {
			key = tolower($2)
			if (!(key in target)) order[++n] = key
			name[key] = $2
			target[key] = (NF >= 3 ? $3 : $2)
		}
		END { for (i = 1; i <= n; i++) printf "%s\t%s\n", name[order[i]], target[order[i]] }
	'
}

# The catalogue entry NAME (case-insensitive) as NAME<TAB>TARGET; fails when it is not there.
vscode_entry() { # NAME
	local name target
	while IFS=$'\t' read -r name target; do
		if foundation_ieq "$name" "$1"; then
			printf '%s\t%s\n' "$name" "$target"
			return 0
		fi
	done < <(vscode_catalogue)
	return 1
}

# The catalogue names the last `deploy` line for this machine type lists, one per line.
vscode_selected() {
	local file names name
	file=$(conf_path vscode-profiles.conf) || return 0
	names=$(conf_value "$file" deploy) || return 0
	for name in $names; do printf '%s\n' "$name"; done
}

# The VS Code command line: `code` on PATH, else the one inside the app bundle. FOUNDATION_VSCODE_CLI,
# when set, is the only candidate (the suites' seam: trimming PATH cannot hide the app's own `code`).
vscode_cli() {
	local cli
	if [ -n "${FOUNDATION_VSCODE_CLI:-}" ]; then
		cli=$FOUNDATION_VSCODE_CLI
	else
		cli=$(command -v code 2>/dev/null) || cli="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
	fi
	[ -x "$cli" ] || return 1
	printf '%s' "$cli"
}

# Succeeds while VS Code runs (it rewrites its profile list from memory then).
vscode_running() {
	pgrep -x Code >/dev/null 2>&1 || pgrep -f "Visual Studio Code.app/Contents/MacOS/" >/dev/null 2>&1
}

# The folder of the VS Code profile NAME. Default is the user data folder; any other name is
# looked up (case-insensitively) in userDataProfiles of globalStorage/storage.json. Fails for a
# name VS Code does not know, unless REGISTER is 1: then the profile is added to that list with
# the location foundation-<name> and its folder is created. Registration refuses while VS Code runs,
# backs storage.json up first (category VSCodeProfiles) and keeps every other key as read; a
# missing storage.json is created. Usage: vscode_profile_location NAME USER-DATA [REGISTER]
vscode_profile_location() {
	local name=$1 user_data=$2 register=${3:-0} storage location tmp written
	if foundation_ieq "$name" Default; then
		printf '%s' "$user_data"
		return 0
	fi
	command -v jq >/dev/null 2>&1 || {
		log_error "jq is needed to read VS Code's profile list - brew install jq"
		return 1
	}
	storage=$user_data/globalStorage/storage.json
	if [ -f "$storage" ]; then
		location=$(jq -r --arg n "$(foundation_lower "$name")" \
			'first(.userDataProfiles[]? | select(((.name // "") | ascii_downcase) == $n and (.location // "") != "") | .location) // empty' \
			"$storage" 2>/dev/null) || {
			log_error "Could not read VS Code's profile list [$storage]"
			return 1
		}
		if [ -n "$location" ]; then
			printf '%s' "$user_data/profiles/$location"
			return 0
		fi
	fi
	[ "$register" -eq 1 ] || return 1
	if vscode_running; then
		log_error "VS Code is running - quit it so profile [$name] can be registered (VS Code rewrites its profile list from memory while it runs)!"
		return 1
	fi
	location=foundation-$(foundation_lower "$name" | LC_ALL=C sed 's/[^a-z0-9-]/-/g')
	mkdir -p "$(dirname "$storage")" || return 1
	if [ -f "$storage" ]; then
		backup_item VSCodeProfiles storage.json "$storage" >/dev/null || {
			log_error "Could not back up $storage - profile [$name] not registered"
			return 1
		}
	fi
	tmp=$storage.foundation.$$
	written=1
	if [ -f "$storage" ]; then
		jq --arg n "$name" --arg l "$location" '.userDataProfiles = ((.userDataProfiles // []) + [{location: $l, name: $n}])' "$storage" >"$tmp" || written=0
	else
		jq -n --arg n "$name" --arg l "$location" '{userDataProfiles: [{location: $l, name: $n}]}' >"$tmp" || written=0
	fi
	if [ "$written" -eq 0 ] || ! mv "$tmp" "$storage"; then
		rm -f "$tmp"
		log_error "Could not register VS Code profile [$name] in $storage"
		return 1
	fi
	mkdir -p "$user_data/profiles/$location" || return 1
	# On stderr: stdout carries the location to the caller.
	log_success "Registered VS Code profile [$name] => [$user_data/profiles/$location]" >&2
	printf '%s' "$user_data/profiles/$location"
}

# The files a profile folder maps onto, as NAME<TAB>REPO<TAB>LIVE<TAB>file|dir lines:
# settings.json, keybindings.json, tasks.json and snippets/. On macOS keybindings.macos.json
# is used when the folder carries it, keybindings.json otherwise. extensions.txt is deployed by
# the extension commands, not linked. Usage: vscode_items SOURCE LOCATION
vscode_items() {
	local source=$1 location=$2 keybindings=keybindings.json
	[ "$(uname -s)" = Darwin ] && [ -e "$source/keybindings.macos.json" ] && keybindings=keybindings.macos.json
	printf '%s\t%s\t%s\t%s\n' \
		settings.json "$source/settings.json" "$location/settings.json" file \
		keybindings.json "$source/$keybindings" "$location/keybindings.json" file \
		tasks.json "$source/tasks.json" "$location/tasks.json" file \
		snippets "$source/snippets" "$location/snippets" dir
}

# The entries of an extensions.txt as ID<TAB>VERSION lines (VERSION empty when unpinned): `#`
# starts a comment, blank lines are skipped, `id@version` pins. Usage: vscode_extension_list FILE
vscode_extension_list() {
	awk '{
		line = $0; sub(/#.*/, "", line); gsub(/^[ \t\r]+|[ \t\r]+$/, "", line)
		if (line == "") next
		at = index(line, "@")
		if (at) { id = substr(line, 1, at - 1); version = substr(line, at + 1) } else { id = line; version = "" }
		gsub(/[ \t]+$/, "", id); gsub(/^[ \t]+/, "", version)
		printf "%s\t%s\n", id, version
	}' "$1"
}

# The extensions VS Code profile TARGET has installed, as ID<TAB>VERSION lines; fails when the
# command line fails (a profile VS Code does not know), so "none installed" is not "could not
# ask". Usage: vscode_installed CLI TARGET
vscode_installed() {
	local cli=$1 target=$2 listing
	local arguments=(--list-extensions --show-versions)
	foundation_ieq "$target" Default || arguments+=(--profile "$target")
	listing=$("$cli" "${arguments[@]}" 2>/dev/null) || {
		log_debug "code --list-extensions failed for profile [$target]"
		return 1
	}
	printf '%s\n' "$listing" | awk 'NF { at = index($0, "@"); if (at) printf "%s\t%s\n", substr($0, 1, at - 1), substr($0, at + 1); else printf "%s\t\n", $0 }'
}

# Merges installed extension ids (stdin, one per line, a trailing @version ignored) into the
# lines of extensions.txt FILE and prints the new list: blank and comment lines stay where they
# are, an entry still installed is kept as written (pin and comment included), an entry no longer
# installed is dropped, and installed ids the file does not name are appended sorted. Ids compare
# case-insensitively; an id listed twice keeps its first line. FILE may be missing.
# Usage: printf '%s\n' ids | vscode_merge_extensions FILE
vscode_merge_extensions() {
	local file=$1 installed
	[ -f "$file" ] || file=/dev/null
	installed=$(awk '{ sub(/@.*/, ""); gsub(/^[ \t\r]+|[ \t\r]+$/, ""); if ($0 != "") print }')
	printf '%s\n' "$installed" | awk -v list="$file" '
		BEGIN {
			while ((getline id < "/dev/stdin") > 0) if (id != "") have[tolower(id)] = id
			while ((getline raw < list) > 0) {
				entry = raw; sub(/#.*/, "", entry); gsub(/^[ \t\r]+|[ \t\r]+$/, "", entry)
				if (entry == "") { print raw; continue }
				id = entry; sub(/@.*/, "", id); gsub(/[ \t]+$/, "", id); key = tolower(id)
				if ((key in have) && !(key in listed)) { listed[key] = 1; print raw }
			}
			fflush()
			sorter = "LC_ALL=C sort -f"
			for (key in have) if (!(key in listed)) print have[key] | sorter
			close(sorter)
		}'
}
