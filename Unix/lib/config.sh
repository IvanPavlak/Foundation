# shellcheck shell=bash
# Readers for the per-domain config files under Unix/config (see docs/foundation/configuration.md).
#
# Format shared by every file: `#` starts a comment line, blank lines are ignored, `[Name]`
# opens a section (names compare case-insensitively, like PowerShell hashtable keys), every
# other line is data whose fields are separated by whitespace.
#
# A file NAME.conf may be accompanied by NAME.local.conf: its sections REPLACE same-named
# sections of the base file and add new ones - the Configuration.local.psd1 idea, per file. A
# generic repository keeps the overlays out of git; a personal fork (Dotfiles) commits them.
#
# A data line of any file may start with @TYPE (or @TYPE,TYPE): it then applies only on those
# machine types (config/machines.conf) and the token is dropped; every reader below applies the
# filter. Split a line into fields with `read -r first second rest <<<"$line"`: the last variable
# keeps the remainder with its spaces, and nothing is glob-expanded.

# Path of a config file; prints nothing and fails when it does not exist.
# Usage: conf_path workspaces.conf
conf_path() {
	local path=$FOUNDATION_CONFIG_DIR/$1
	[ -r "$path" ] || return 1
	printf '%s' "$path"
}

conf__local_path() {
	local base=$1
	printf '%s' "${base%.conf}.local.conf"
}

# Section names of a file (base plus local overlay), in file order, without duplicates.
# Usage: conf_sections FILE
conf_sections() {
	local file=$1 local_file
	local_file=$(conf__local_path "$file")
	local files=("$file")
	[ -r "$local_file" ] && files+=("$local_file")
	awk '
		/^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
			name = $0; sub(/^[[:space:]]*\[/, "", name); sub(/\][[:space:]]*$/, "", name)
			key = tolower(name)
			if (!(key in seen)) { seen[key] = 1; print name }
		}
	' "${files[@]}"
}

# Data lines of one section for this machine type, trimmed, comments and blanks removed. The
# local overlay wins when it defines the section. Fails when the section exists in neither file;
# a section whose lines are all for other machine types succeeds with no output.
# Usage: conf_section FILE NAME
conf_section() {
	local lines
	lines=$(conf__section_raw "$1" "$2") || return 1
	[ -n "$lines" ] || return 0
	printf '%s\n' "$lines" | conf_for_machine
}

conf__section_raw() {
	local file=$1 name=$2 local_file source
	local_file=$(conf__local_path "$file")
	for source in "$local_file" "$file"; do
		[ -r "$source" ] || continue
		if awk -v want="$(foundation_lower "$name")" '
			/^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
				n = $0; sub(/^[[:space:]]*\[/, "", n); sub(/\][[:space:]]*$/, "", n)
				inside = (tolower(n) == want); if (inside) found = 1; next
			}
			inside && !/^[[:space:]]*(#|$)/ { sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); print }
			END { exit found ? 0 : 1 }
		' "$source"; then
			return 0
		fi
	done
	return 1
}

# The exact section name as written in the file (for display), matched case-insensitively.
conf_section_name() {
	local file=$1 name=$2 section
	while IFS= read -r section; do
		if foundation_ieq "$section" "$name"; then
			printf '%s' "$section"
			return 0
		fi
	done < <(conf_sections "$file")
	return 1
}

# Data lines of a file that has no sections (or of the part before the first section) for this
# machine type, base file then local overlay. A line `-LINE` removes every earlier line equal to
# LINE (whitespace runs and case ignored), so an overlay can take back a line of the base file -
# the `-<id>` rows of the Windows .local.csv overlays: `-item /Applications/Tailscale.app hidden`.
# Usage: conf_lines FILE
conf_lines() {
	conf__lines_raw "$1" | conf_for_machine | conf__apply_removals
}

# Everything conf_lines reads for Unix/config/NAME, as one string in CONF_CACHE_KEY: the file's
# path, the contents of the file, its overlay and machines.conf (read with builtins, no process)
# and the machine type variables. Lines kept from an earlier conf_lines hold while it is
# unchanged, so a file written during the process is read again. Fails when NAME does not exist.
# Usage: conf_cache_key NAME
conf_cache_key() {
	local file=$FOUNDATION_CONFIG_DIR/$1 base='' overlay='' machines=''
	[ -r "$file" ] || return 1
	IFS= read -r -d '' base <"$file" || true
	[ -r "${file%.conf}.local.conf" ] && { IFS= read -r -d '' overlay <"${file%.conf}.local.conf" || true; }
	[ -r "$FOUNDATION_CONFIG_DIR/machines.conf" ] && { IFS= read -r -d '' machines <"$FOUNDATION_CONFIG_DIR/machines.conf" || true; }
	CONF_CACHE_KEY="$file|${CONF_MACHINE_TYPE:-}|${FOUNDATION_MACHINE_TYPE:-}|${MACHINE_TYPE:-}|$base|$overlay|$machines"
}

# conf_lines of Unix/config/zones.conf, read once per process: a layout drawn or checked asks it
# for every desktop and entry, and one conf_lines costs several processes. Sets ZONES_CACHED to
# the lines, read again when conf_cache_key changes. Kept in the calling shell: a call inside
# $(...) still answers right but keeps nothing, so a command that asks in a loop of subshells
# loads it once first. Fails when there is no zones.conf. Usage: zones_cache_load
ZONES__CACHE_KEY=''
ZONES_CACHED=''
zones_cache_load() {
	conf_cache_key zones.conf || return 1
	[ "$CONF_CACHE_KEY" = "$ZONES__CACHE_KEY" ] && return 0
	ZONES_CACHED=$(conf_lines "$FOUNDATION_CONFIG_DIR/zones.conf")
	ZONES__CACHE_KEY=$CONF_CACHE_KEY
}

# Prints ZONES_CACHED as conf_lines would (nothing for no lines). Usage: zones_cache_load && zones_cached_lines | ...
zones_cached_lines() {
	[ -z "$ZONES_CACHED" ] || printf '%s\n' "$ZONES_CACHED"
}

# The `-LINE` removals of conf_lines for lines on stdin; input without one passes untouched. A
# `[Name]` line ends the part removals apply to (conf_effective's sections are never trimmed).
conf__apply_removals() {
	local input
	input=$(cat)
	[ -n "$input" ] || return 0
	case $'\n'$input in
		*$'\n-'*) ;;
		*)
			printf '%s\n' "$input"
			return 0
			;;
	esac
	printf '%s\n' "$input" | awk '
		function norm(text) { gsub(/[[:space:]]+/, " ", text); return tolower(text) }
		/^\[/ { insec = 1 }
		!insec && /^-/ {
			gone = norm(substr($0, 2)); sub(/^ /, "", gone)
			for (i = 1; i <= n; i++) if (keep[i] && norm(line[i]) == gone) keep[i] = 0
			next
		}
		{ line[++n] = $0; keep[n] = 1 }
		END { for (i = 1; i <= n; i++) if (keep[i]) print line[i] }
	'
}

conf__lines_raw() {
	local file=$1 local_file
	local_file=$(conf__local_path "$file")
	awk '
		/^[[:space:]]*\[[^]]+\][[:space:]]*$/ { exit }
		!/^[[:space:]]*(#|$)/ { sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); print }
	' "$file"
	if [ -r "$local_file" ]; then
		awk '
			/^[[:space:]]*\[[^]]+\][[:space:]]*$/ { exit }
			!/^[[:space:]]*(#|$)/ { sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); print }
		' "$local_file"
	fi
}

# Value of the last `KEY value...` line for this machine type in a sectionless file (base, then
# overlay, so the overlay wins; the key compares case-insensitively); a bare `KEY` line gives an
# empty value. Fails when no line has the key. Usage: conf_value FILE KEY
# FOUNDATION_SETTING_OVERRIDES ("key=value" lines) beats every file: Measure-WorkspaceOpen runs each
# variant with its values this way, so no config file is ever rewritten for an experiment.
conf_value() {
	local line key rest value='' found=1
	if [ -n "${FOUNDATION_SETTING_OVERRIDES:-}" ]; then
		value=$(printf '%s\n' "$FOUNDATION_SETTING_OVERRIDES" | awk -F= -v k="$(foundation_lower "$2")" 'tolower($1) == k { sub(/^[^=]*=/, ""); v = $0; hit = 1 } END { if (hit) print v; exit !hit }') && {
			printf '%s' "$value"
			return 0
		}
	fi
	while IFS= read -r line; do
		read -r key rest <<<"$line"
		if foundation_ieq "$key" "$2"; then
			value=$rest
			found=0
		fi
	done < <(conf_lines "$1")
	[ $found -eq 0 ] || return 1
	printf '%s' "$value"
}

# The whole effective file, for readers that walk every section in one pass: the sectionless
# lines (base, then overlay), then every section in conf_sections order as `[Name]` and its data
# lines, an overlay section in place of the base one, all filtered for this machine type and
# with the -LINE removals of the sectionless part applied. Comments and blanks are dropped.
# Usage: conf_effective FILE
conf_effective() {
	local file=$1 local_file files
	local_file=$(conf__local_path "$file")
	files=("$file")
	[ -r "$local_file" ] && files=("$local_file" "$file")
	awk -v overlay=$((${#files[@]} - 1)) '
		FNR == 1 { pass++; cur = "" }
		/^[[:space:]]*(#|$)/ { next }
		/^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
			name = $0; sub(/^[[:space:]]*\[/, "", name); sub(/\][[:space:]]*$/, "", name)
			cur = tolower(name)
			if (overlay && pass == 1) {
				if (!(cur in lsec)) { lorder[++ln] = cur; lname[cur] = name; lsec[cur] = "" }
			} else if (!(cur in bsec)) { border[++bn] = cur; bname[cur] = name; bsec[cur] = "" }
			next
		}
		{
			line = $0; sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line)
			if (overlay && pass == 1) {
				if (cur == "") lpre[++lp] = line; else lsec[cur] = lsec[cur] line "\n"
			} else if (cur == "") bpre[++bp] = line; else bsec[cur] = bsec[cur] line "\n"
		}
		END {
			for (i = 1; i <= bp; i++) print bpre[i]
			for (i = 1; i <= lp; i++) print lpre[i]
			for (i = 1; i <= bn; i++) {
				k = border[i]; print "[" bname[k] "]"
				printf "%s", ((k in lsec) ? lsec[k] : bsec[k])
			}
			for (i = 1; i <= ln; i++) {
				k = lorder[i]; if (k in bsec) continue
				print "[" lname[k] "]"; printf "%s", lsec[k]
			}
		}
	' "${files[@]}" | conf_for_machine | conf__apply_removals
}

# Machine-type filter for lines on stdin: a line starting with @TYPE[,TYPE...] is printed
# without that token when the current machine type is one of them and dropped otherwise; every
# other line passes. CONF_MACHINE_TYPE overrides the machine type (tests, previews). Input
# without an @ line passes untouched and never resolves the machine type.
# Usage: ... | conf_for_machine
conf_for_machine() {
	local input machine
	input=$(cat)
	[ -n "$input" ] || return 0
	case $'\n'$input in
		*$'\n@'*) ;;
		*)
			printf '%s\n' "$input"
			return 0
			;;
	esac
	machine=$(foundation_lower "${CONF_MACHINE_TYPE:-$(foundation_machine_type)}")
	# A token that is no `type` line skips its line silently; say so at the verbose level, as
	# Test-MachineTypeScope reports an unknown scope token at use (Test-ConfigurationSchema
	# reports it as a problem).
	case ${FOUNDATION_LOG_LEVEL:-normal} in
		verbose | debug) conf__debug_unknown_tokens "$input" ;;
	esac
	printf '%s\n' "$input" | awk -v machine="$machine" '
		/^@/ {
			n = split(substr($1, 2), types, ",")
			for (i = 1; i <= n; i++) {
				if (tolower(types[i]) == machine) {
					sub(/^@[^[:space:]]*[[:space:]]*/, "")
					if ($0 != "") print
					break
				}
			}
			next
		}
		{ print }
	'
}

# One debug line per @TYPE token of INPUT that is no `type` line of machines.conf; nothing without
# type lines. Usage: conf__debug_unknown_tokens INPUT
conf__debug_unknown_tokens() {
	local types token
	types=$(foundation_machine_types | tr '[:upper:]' '[:lower:]')
	[ -n "$types" ] || return 0
	while IFS= read -r token; do
		printf '%s\n' "$types" | grep -qxF -- "$(foundation_lower "$token")" ||
			log_debug "[conf_for_machine] @$token is not a machine type of machines.conf - its lines apply nowhere"
	done < <(printf '%s\n' "$1" | awk '/^@/ { n = split(substr($1, 2), t, ","); for (i = 1; i <= n; i++) if (t[i] != "" && !seen[tolower(t[i])]++) print t[i] }')
}

# ---------------------------------------------------------------------------------------------
# Machine type ({MachineType} placeholder analog) - config/machines.conf
# ---------------------------------------------------------------------------------------------

foundation_hostname() {
	local name=''
	if command -v scutil >/dev/null 2>&1; then
		name=$(scutil --get LocalHostName 2>/dev/null)
	fi
	[ -n "$name" ] || name=$(hostname -s 2>/dev/null)
	printf '%s' "$name"
}

# The machine types of machines.conf, the ValidMachineTypes analog: one per `type` line (base,
# then overlay), first spelling kept, duplicates (in any case) dropped. Prints nothing without
# machines.conf or type lines. Usage: foundation_machine_types
foundation_machine_types() {
	local file
	file=$(conf_path machines.conf) || return 0
	conf__lines_raw "$file" | conf__apply_removals | awk '$1 == "type" && NF >= 2 && !seen[tolower($2)]++ { print $2 }'
}

# Resolution order, same as the Windows DetermineMachineType plus the Unix env override:
#   1. FOUNDATION_MACHINE_TYPE, an explicit per-shell override
#   2. `host <hostname> <type>` in machines.conf
#   3. MACHINE_TYPE, when the environment exports it
#   4. `default <type>`, else Test (the profile every repository ships)
# A result that is no `type` line of machines.conf (a typo such as FOUNDATION_MACHINE_TYPE=work2)
# is still returned, with a warning on stderr naming where it came from, as Windows'
# DetermineMachineType rejects an unknown type: once per process, or once per `w` run.
foundation_machine_type() {
	local file line host fallback=''
	if [ -n "${FOUNDATION_MACHINE_TYPE:-}" ]; then
		printf '%s' "$FOUNDATION_MACHINE_TYPE"
		foundation__check_machine_type "$FOUNDATION_MACHINE_TYPE" FOUNDATION_MACHINE_TYPE
		return 0
	fi
	file=$(conf_path machines.conf) || {
		printf '%s' "${MACHINE_TYPE:-Test}"
		return 0
	}
	host=$(foundation_hostname)
	# Read raw: the @TYPE filter of the other readers needs the machine type this resolves.
	while IFS= read -r line; do
		set -- $line
		if [ "$1" = "host" ] && foundation_ieq "$2" "$host"; then
			printf '%s' "$3"
			foundation__check_machine_type "$3" "the host $2 line of machines.conf"
			return 0
		fi
		[ "$1" = default ] && fallback=$2
	done < <(conf__lines_raw "$file")
	if [ -n "${MACHINE_TYPE:-}" ]; then
		printf '%s' "$MACHINE_TYPE"
		foundation__check_machine_type "$MACHINE_TYPE" MACHINE_TYPE
		return 0
	fi
	printf '%s' "${fallback:-Test}"
	foundation__check_machine_type "${fallback:-Test}" "${fallback:+the default line of machines.conf}"
}

# Warns on stderr when TYPE is not a `type` line of machines.conf (nothing without type lines),
# once per process: a marker under FOUNDATION_RUN_DIR (one warning per `w` run), else under TMPDIR
# by process id; the marker is only made when there is something to warn about.
# Usage: foundation__check_machine_type TYPE [SOURCE]
foundation__check_machine_type() {
	local types marker
	types=$(foundation_machine_types)
	[ -n "$types" ] || return 0
	printf '%s\n' "$types" | grep -qixF -- "$1" && return 0
	if [ -n "${FOUNDATION_RUN_DIR:-}" ] && [ -d "$FOUNDATION_RUN_DIR" ]; then
		marker=$FOUNDATION_RUN_DIR/machine-type-warned
	else
		marker=${TMPDIR:-/tmp}/foundation-machine-type-warned.$$
	fi
	[ -e "$marker" ] && return 0
	: >"$marker" 2>/dev/null
	log_warning "Machine type [$1]${2:+ (from $2)} is not a type line of machines.conf ($(printf '%s' "$types" | tr '\n' ' ' | sed 's/ $//')) - add a type line for it or fix the name" >&2
}

# The dev root, the {Dev} placeholder of Windows (BasePaths.<Type>.Dev) that a configured path
# names as $DEV: the last `dev-root PATH` line of machines.conf for this machine type (overlay
# wins, `@TYPE dev-root` per type), else the folder that holds this clone - what the Windows first
# run records. A `$DEV` inside the line itself means that folder. Usage: foundation_dev_root
foundation_dev_root() {
	local file value='' parent
	parent=$(dirname "$DOTFILES_ROOT")
	file=$(conf_path machines.conf) && value=$(conf_value "$file" dev-root 2>/dev/null) || value=''
	if [ -z "$value" ]; then
		printf '%s' "$parent"
		return 0
	fi
	foundation__dev_root=$parent foundation_expand_path "$value"
}
