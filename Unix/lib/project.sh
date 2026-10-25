# shellcheck shell=bash
# Projects (config/projects.conf): paths, actions, terminal tabs and run commands.

project__file() {
	conf_path projects.conf
}

project_names() {
	local file
	file=$(project__file) || return 0
	conf_sections "$file"
}

project_canonical() {
	local file
	file=$(project__file) || return 1
	conf_section_name "$file" "$1"
}

# Lines of one KIND (path, action, tab, run) of a project, without the kind word.
project_lines() {
	local file
	file=$(project__file) || return 1
	conf_section "$file" "$1" | awk -v kind="$2" '$1 == kind { sub(/^[^[:space:]]+[[:space:]]*/, ""); print }'
}

# Expanded directory of path KEY (case-insensitive; ROOT falls back to nothing).
project_path() {
	local name=$1 key=$2 line dir
	while IFS= read -r line; do
		set -- $line
		if foundation_ieq "$1" "$key"; then
			dir=${line#*[[:space:]]}
			dir=$(foundation_trim "$dir")
			foundation_expand_path "$dir"
			return 0
		fi
	done < <(project_lines "$name" path)
	return 1
}

# Tabs of a project as "TITLE<TAB>DIR<TAB>KEY", skipping (with a warning) keys without a path.
project_tabs() {
	local name=$1 canonical line key dir
	canonical=$(project_canonical "$name") || return 1
	while IFS= read -r line; do
		key=${line%%[[:space:]]*}
		dir=''
		if [ "$key" != "$line" ]; then
			dir=$(foundation_trim "${line#*[[:space:]]}")
		fi
		if [ -n "$dir" ]; then
			dir=$(foundation_expand_path "$dir")
		elif [ "$key" = "DEFAULT" ]; then
			dir=$HOME
		else
			dir=$(project_path "$canonical" "$key") || dir=''
		fi
		if [ -z "$dir" ] || [ ! -d "$dir" ]; then
			log_warning "  Skipping [$canonical.$key] (path not found => [$dir])" >&2
			continue
		fi
		printf '%s.%s\t%s\t%s\n' "$canonical" "$key" "$dir" "$key"
	done < <(project_lines "$canonical" tab)
}

# Titles of the project tabs PROJECT opens ("<Project>.<KEY>", as project_tabs names them), with
# no path check: a tab that is open already is recognised by its title alone.
# Usage: project_tab_titles PROJECT
project_tab_titles() {
	local canonical line
	canonical=$(project_canonical "$1") || return 1
	while IFS= read -r line; do
		[ -n "$line" ] && printf '%s.%s\n' "$canonical" "${line%%[[:space:]]*}"
	done < <(project_lines "$canonical" tab)
	return 0
}

# Run command for tab KEY, empty when none.
project_run_command() {
	local name=$1 key=$2 line
	while IFS= read -r line; do
		if foundation_ieq "${line%%[[:space:]]*}" "$key"; then
			foundation_trim "${line#*[[:space:]]}"
			return 0
		fi
	done < <(project_lines "$name" run)
	return 1
}

project_runnable() {
	local name
	while IFS= read -r name; do
		[ -n "$(project_lines "$name" run)" ] && printf '%s\n' "$name"
	done < <(project_names)
}
