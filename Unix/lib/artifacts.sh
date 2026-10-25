# shellcheck shell=bash
# The AI artifacts mechanism shared by Deploy-AiArtifacts, Update-AiArtifacts and List-AiArtifacts
# (docs/unix/ai.md): the artifacts root, the roster of each kind, the harness definitions of
# ai-harnesses.conf and the deployment plan built from both. Needs lib/config.sh.
#
# An artifact is an item folder <root>/<Kind>/<source>/<item>. The sources read are `own` first,
# then `foundation` (the product skills), `example` and the [sections] of ai-artifacts.conf in name
# order; the first source wins an item name two of them carry. Any other source folder (WinuX's
# `winux` in a repository that carries both halves) is not read.

# The kinds, in deployment order, space-separated.
ai_kinds() {
	printf 'skills mods rules prompts agents'
}

# The folder of KIND under the root (Skills, Mods, ...); fails for an unknown kind.
# Usage: ai_kind_folder KIND
ai_kind_folder() {
	case $(foundation_lower "$1") in
		skills) printf 'Skills' ;;
		mods) printf 'Mods' ;;
		rules) printf 'Rules' ;;
		prompts) printf 'Prompts' ;;
		agents) printf 'Agents' ;;
		*) return 1 ;;
	esac
}

# The portable file of a KIND item: SKILL.md, .claude-plugin/plugin.json, RULES.md, PROMPT.md,
# AGENT.md. Usage: ai_kind_file KIND
ai_kind_file() {
	case $(foundation_lower "$1") in
		skills) printf 'SKILL.md' ;;
		mods) printf '.claude-plugin/plugin.json' ;;
		rules) printf 'RULES.md' ;;
		prompts) printf 'PROMPT.md' ;;
		agents) printf 'AGENT.md' ;;
	esac
}

# Whether DIR is an item of KIND: a skill holds SKILL.md, a mod .claude-plugin/plugin.json, a rules,
# prompt or agent item at least one file (its variants). Usage: ai_is_item KIND DIR
ai_is_item() {
	[ -d "$2" ] || return 1
	case $(foundation_lower "$1") in
		skills) [ -f "$2/SKILL.md" ] ;;
		mods) [ -f "$2/.claude-plugin/plugin.json" ] ;;
		*) [ -n "$(find "$2" -mindepth 1 -maxdepth 1 -type f ! -name '.*' -print 2>/dev/null | head -n 1)" ] ;;
	esac
}

# Path of ai-artifacts.conf (fails when there is none).
ai__conf() { conf_path ai-artifacts.conf; }

# The artifacts root: the last `root PATH` line of ai-artifacts.conf, expanded; AI of the
# repository when there is none.
ai_root() {
	local file value
	if file=$(ai__conf) && value=$(conf_value "$file" root) && [ -n "$value" ]; then
		foundation_expand_path "$value"
		return 0
	fi
	printf '%s' "$DOTFILES_ROOT/AI"
}

# The harnesses this machine deploys into, one per line: the last `deploy` line for this machine
# type. Nothing without one.
ai_deployed_harnesses() {
	local file value
	file=$(ai__conf) && value=$(conf_value "$file" deploy) || return 0
	# shellcheck disable=SC2086
	[ -z "$value" ] || printf '%s\n' $value
}

# The `exclude` entries of ai-artifacts.conf, lowercased, one per line (KIND/NAME or
# KIND/SOURCE/NAME).
ai_excludes() {
	local file line key rest
	file=$(ai__conf) || return 0
	while IFS= read -r line; do
		read -r key rest <<<"$line"
		foundation_ieq "$key" exclude || continue
		# shellcheck disable=SC2086
		[ -z "$rest" ] || printf '%s\n' $rest | tr '[:upper:]' '[:lower:]'
	done < <(conf_lines "$file")
}

# The item a `file` destination of KIND takes: the NAME of the last `use KIND NAME` line; fails
# without one. Usage: ai_used KIND
ai_used() {
	local file line key kind name found=''
	file=$(ai__conf) || return 1
	while IFS= read -r line; do
		read -r key kind name _ <<<"$line"
		foundation_ieq "$key" use && foundation_ieq "$kind" "$1" && [ -n "$name" ] && found=$name
	done < <(conf_lines "$file")
	[ -n "$found" ] || return 1
	printf '%s' "$found"
}

# The vendored sources: the [sections] of ai-artifacts.conf, one per line.
ai_vendored_sources() {
	local file
	file=$(ai__conf) || return 0
	conf_sections "$file"
}

# The source folders read for KIND, one per line: own first, then foundation, example and the
# vendored sources in name order, each only when its folder exists. Usage: ai_sources KIND
ai_sources() {
	local base allowed dir name
	base=$(ai_root)/$(ai_kind_folder "$1") || return 1
	[ -d "$base" ] || return 0
	allowed=$'\nfoundation\nexample\n'$(ai_vendored_sources | tr '[:upper:]' '[:lower:]')$'\n'
	[ -d "$base/own" ] && printf 'own\n'
	for dir in "$base"/*/; do
		name=${dir%/}
		name=${name##*/}
		[ "$name" != own ] || continue
		case $allowed in *$'\n'"$(foundation_lower "$name")"$'\n'*) printf '%s\n' "$name" ;; esac
	done | LC_ALL=C sort -f
}

# The roster of KIND: SOURCE<TAB>ITEM<TAB>DIR per item deployed, sources in ai_sources order, items
# in name order, the `exclude` lines applied; the first source wins an item name two carry, and the
# loser prints DUPLICATE<TAB>ITEM<TAB>DIR<TAB>KEPT-SOURCE. Usage: ai_roster KIND
ai_roster() {
	local kind base excludes source dir item seen=$'\n' kept lower
	kind=$(foundation_lower "$1")
	base=$(ai_root)/$(ai_kind_folder "$kind") || return 1
	excludes=$'\n'$(ai_excludes)$'\n'
	while IFS= read -r source; do
		for dir in "$base/$source"/*/; do
			dir=${dir%/}
			ai_is_item "$kind" "$dir" || continue
			item=${dir##*/}
			lower=$(foundation_lower "$item")
			case $excludes in
				*$'\n'"$kind/$lower"$'\n'* | *$'\n'"$kind/$(foundation_lower "$source")/$lower"$'\n'*) continue ;;
			esac
			# seen holds one ITEM<TAB>SOURCE line per winner, lowercased item.
			case $seen in
				*$'\n'"$lower"$'\t'*)
					kept=${seen#*$'\n'"$lower"$'\t'}
					printf 'DUPLICATE\t%s\t%s\t%s\n' "$item" "$dir" "${kept%%$'\n'*}"
					continue
					;;
			esac
			seen+="$lower"$'\t'"$source"$'\n'
			printf '%s\t%s\t%s\n' "$source" "$item" "$dir"
		done
	done < <(ai_sources "$kind")
}

# The destinations of harness NAME: KIND<TAB>PLACEMENT<TAB>FILES<TAB>HOOKS<TAB>PATH per line of
# its section (HOOKS comma-separated without the +, `-` for none; PATH expanded), INVALID<TAB>LINE
# for a line that is not KIND PLACEMENT FILES [+HOOK...] PATH. Fails when the section does not
# exist. Usage: ai_harness_destinations NAME
ai_harness_destinations() {
	local file lines line kind placement files rest hook hooks
	file=$(conf_path ai-harnesses.conf) || return 1
	lines=$(conf_section "$file" "$1") || return 1
	[ -n "$lines" ] || return 0
	while IFS= read -r line; do
		read -r kind placement files rest <<<"$line"
		hooks=''
		while [[ $rest == +* ]]; do
			read -r hook rest <<<"$rest"
			hooks+="${hooks:+,}${hook#+}"
		done
		kind=$(foundation_lower "$kind")
		placement=$(foundation_lower "$placement")
		if ! ai_kind_folder "$kind" >/dev/null || [ -z "$rest" ] || [ -z "$files" ]; then
			printf 'INVALID\t%s\n' "$line"
			continue
		fi
		case $placement in each | copy | file) ;; *)
			printf 'INVALID\t%s\n' "$line"
			continue
			;;
		esac
		printf '%s\t%s\t%s\t%s\t%s\n' "$kind" "$placement" "$files" "${hooks:--}" "$(foundation_expand_path "$rest")"
	done <<<"$lines"
}

# The file of item DIR a destination takes: the first of FILES (comma-separated) the item has, `.`
# being DIR itself; fails when it has none. Usage: ai_item_file DIR FILES
ai_item_file() {
	local dir=$1 name
	local -a names
	IFS=, read -r -a names <<<"$2"
	for name in "${names[@]}"; do
		if [ "$name" = . ]; then
			printf '%s' "$dir"
			return 0
		fi
		if [ -f "$dir/$name" ]; then
			printf '%s' "$dir/$name"
			return 0
		fi
	done
	return 1
}

# The name an item gets in an `each` destination: ITEM for the folder itself, else ITEM plus the
# extension of the file taken (everything from its first dot: claude.md gives .md,
# copilot.agent.md gives .agent.md). Usage: ai_link_name ITEM DIR SOURCE-PATH
ai_link_name() {
	local file
	if [ "$3" = "$2" ]; then
		printf '%s' "$1"
		return 0
	fi
	file=${3##*/}
	case $file in
		*.*) printf '%s.%s' "$1" "${file#*.}" ;;
		*) printf '%s' "$1" ;;
	esac
}

# The deployment plan, one TAB-separated record per line, for the harnesses of the `deploy` line
# (KIND... limits it to those kinds):
#   WARN<TAB>MESSAGE                       a problem of the configuration or the roster
#   NOTE<TAB>MESSAGE                       something left out on purpose
#   DEST<TAB>KIND<TAB>PLACEMENT<TAB>HOOKS<TAB>PATH<TAB>HARNESS
#                                          a destination; the ITEM records after it belong to it
#   ITEM<TAB>KIND<TAB>NAME<TAB>SOURCE<TAB>TARGET
#                                          SOURCE (an item folder or file) goes to TARGET
# A destination two harnesses name is planned once, for the first. Usage: ai_plan [KIND...]
ai_plan() {
	local -A rosters=() planned=()
	local kinds=" $* " harness line kind placement files hooks path entry source item dir kept used found
	local -a destinations=()
	while IFS= read -r harness; do
		if ! conf_section "$(conf_path ai-harnesses.conf 2>/dev/null || printf none)" "$harness" >/dev/null 2>&1; then
			printf 'WARN\tHarness [%s] of the deploy line is no section of ai-harnesses.conf - skipped\n' "$harness"
			continue
		fi
		found=0
		while IFS= read -r line; do
			if [[ $line == INVALID$'\t'* ]]; then
				printf 'WARN\tHarness [%s]: not KIND PLACEMENT FILES [+HOOK...] PATH => %s\n' "$harness" "${line#*$'\t'}"
				continue
			fi
			found=1
			IFS=$'\t' read -r kind placement files hooks path <<<"$line"
			[ "$kinds" = '  ' ] || [[ $kinds == *" $kind "* ]] || continue
			if [ -n "${planned[$path]:-}" ]; then
				[ "${planned[$path]}" = "$kind"$'\t'"$placement"$'\t'"$files" ] ||
					printf 'WARN\tHarness [%s] names %s differently from an earlier harness - the first definition is kept\n' "$harness" "$path"
				continue
			fi
			planned[$path]=$kind$'\t'$placement$'\t'$files
			destinations+=("$line"$'\t'"$harness")
		done < <(ai_harness_destinations "$harness")
		[ "$found" -eq 1 ] || printf 'NOTE\tHarness [%s] has no destination for this machine type\n' "$harness"
	done < <(ai_deployed_harnesses)

	for entry in "${destinations[@]}"; do
		IFS=$'\t' read -r kind placement files hooks path harness <<<"$entry"
		if [ -z "${rosters[$kind]+set}" ]; then
			rosters[$kind]=''
			while IFS=$'\t' read -r source item dir kept; do
				if [ "$source" = DUPLICATE ]; then
					printf 'WARN\tDuplicate %s [%s] in %s - keeping the one from [%s]\n' "${kind%s}" "$item" "${dir%/*}" "$kept"
					continue
				fi
				rosters[$kind]+="$source"$'\t'"$item"$'\t'"$dir"$'\n'
			done < <(ai_roster "$kind")
		fi
		printf 'DEST\t%s\t%s\t%s\t%s\t%s\n' "$kind" "$placement" "$hooks" "$path" "$harness"
		if [ "$placement" = file ]; then
			if ! used=$(ai_used "$kind"); then
				printf 'NOTE\t%s: no `use %s NAME` line - nothing to link\n' "$path" "$kind"
				continue
			fi
			found=''
			while IFS=$'\t' read -r source item dir; do
				[ -n "$item" ] && foundation_ieq "$item" "$used" && found=$dir && break
			done <<<"${rosters[$kind]}"
			if [ -z "$found" ]; then
				printf 'WARN\t`use %s %s` names no %s item (excluded, or under no source read)\n' "$kind" "$used" "${kind%s}"
				continue
			fi
			if ! source=$(ai_item_file "$found" "$files"); then
				printf 'NOTE\t%s: %s has none of %s - left out\n' "$path" "${found##*/}" "$files"
				continue
			fi
			printf 'ITEM\t%s\t%s\t%s\t%s\n' "$kind" "${found##*/}" "$source" "$path"
			continue
		fi
		while IFS=$'\t' read -r source item dir; do
			[ -n "$item" ] || continue
			entry=$(ai_item_file "$dir" "$files") || continue
			printf 'ITEM\t%s\t%s\t%s\t%s/%s\n' "$kind" "$item" "$entry" "$path" "$(ai_link_name "$item" "$dir" "$entry")"
		done <<<"${rosters[$kind]}"
	done
}
