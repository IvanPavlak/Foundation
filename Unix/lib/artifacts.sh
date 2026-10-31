# shellcheck shell=bash
# The AI artifacts mechanism shared by Deploy-AiArtifacts, Update-AiArtifacts and List-AiArtifacts
# (docs/foundation/ai.md): the artifacts root, the roster of each kind, the harness definitions of
# ai-harnesses.conf and the deployment plan built from both. Needs lib/config.sh.
#
# An artifact is an item folder <root>/<Kind>/<source>/<item>, a folder of a checkout source (a
# local repository linked in place) or a row of a manifest source (a pinned clone in the cache).
# The sources read, in precedence order (the first wins an item name two of them carry): `own`,
# the checkout sources, `foundation` (the product skills), `example`, the vendored [sections] of
# ai-artifacts.conf in name order, then the manifest rows. Any other source folder (WinuX's `winux`
# in a repository that carries both halves) is not read. With an AI profile active (lib/aiprofile.sh,
# loaded by the caller), its deploy, rules, include and exclude lines take part.

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

# The harnesses this machine deploys into, one per line: the active profile's `deploy` lines when
# it has any, else the last `deploy` line for this machine type. Nothing without one.
ai_deployed_harnesses() {
	local file value
	if [ -n "${AI_PROFILE:-}" ] && ai_profile_has deploy; then
		ai_profile_words deploy
		return 0
	fi
	file=$(ai__conf) && value=$(conf_value "$file" deploy) || return 0
	# shellcheck disable=SC2086
	[ -z "$value" ] || printf '%s\n' $value
}

# The `exclude` entries of ai-artifacts.conf and of the active profile, lowercased, one per line
# (KIND/NAME or KIND/SOURCE/NAME).
ai_excludes() {
	local file line key rest
	if [ -n "${AI_PROFILE:-}" ]; then
		ai_profile_words exclude | tr '[:upper:]' '[:lower:]'
	fi
	file=$(ai__conf) || return 0
	while IFS= read -r line; do
		read -r key rest <<<"$line"
		foundation_ieq "$key" exclude || continue
		# shellcheck disable=SC2086
		[ -z "$rest" ] || printf '%s\n' $rest | tr '[:upper:]' '[:lower:]'
	done < <(conf_lines "$file")
}

# The active profile's `include` entries, lowercased, one per line (KIND/NAME or KIND/SOURCE/NAME).
# A kind with an entry deploys only its included items; a kind without one deploys all of them.
ai_includes() {
	[ -n "${AI_PROFILE:-}" ] || return 0
	ai_profile_words include | tr '[:upper:]' '[:lower:]'
}

# The item a `file` destination of KIND takes: for rules the active profile's `rules NAME` line,
# else the NAME of the last `use KIND NAME` line; fails without one. Usage: ai_used KIND
ai_used() {
	local file line key kind name found=''
	if [ -n "${AI_PROFILE:-}" ] && foundation_ieq "$1" rules && found=$(ai_profile_value rules); then
		read -r found _ <<<"$found"
		if [ -n "$found" ]; then
			printf '%s' "$found"
			return 0
		fi
	fi
	file=$(ai__conf) || return 1
	while IFS= read -r line; do
		read -r key kind name _ <<<"$line"
		foundation_ieq "$key" use && foundation_ieq "$kind" "$1" && [ -n "$name" ] && found=$name
	done < <(conf_lines "$file")
	[ -n "$found" ] || return 1
	printf '%s' "$found"
}

# What section NAME of ai-artifacts.conf is, one word per line: `checkout` (it has a checkout
# line), `manifest` (a manifest line) and `vendored` (a repository line, or neither of the other
# two). A section can be a checkout and a manifest source at once. Usage: ai_section_kinds NAME
ai_section_kinds() {
	local file lines line key repository=0 checkout=0 manifest=0
	file=$(ai__conf) || return 0
	lines=$(conf_section "$file" "$1") || return 0
	while IFS= read -r line; do
		read -r key _ <<<"$line"
		case $(foundation_lower "$key") in
			repository) repository=1 ;;
			checkout) checkout=1 ;;
			manifest) manifest=1 ;;
		esac
	done <<<"$lines"
	[ "$checkout" -eq 0 ] || printf 'checkout\n'
	[ "$manifest" -eq 0 ] || printf 'manifest\n'
	if [ "$repository" -eq 1 ] || { [ "$checkout" -eq 0 ] && [ "$manifest" -eq 0 ]; }; then printf 'vendored\n'; fi
}

# The rest of the last KEY line of section NAME of ai-artifacts.conf; fails without one.
# Usage: ai_section_value NAME KEY
ai_section_value() {
	local file line key rest value found=1
	file=$(ai__conf) || return 1
	while IFS= read -r line; do
		read -r key rest <<<"$line"
		if foundation_ieq "$key" "$2"; then
			value=$rest
			found=0
		fi
	done < <(conf_section "$file" "$1" 2>/dev/null)
	[ "$found" -eq 0 ] || return 1
	printf '%s' "$value"
}

# The folders section NAME names for KIND (its `KIND PATH...` line), one per line; `skills` for
# skills when the section has no kind line at all (`skills skills`). Usage: ai_section_folders NAME KIND
ai_section_folders() {
	local value words any kind
	if value=$(ai_section_value "$1" "$2"); then
		read -r -a words <<<"$value"
		[ ${#words[@]} -eq 0 ] || printf '%s\n' "${words[@]}"
		return 0
	fi
	any=0
	for kind in $(ai_kinds); do ai_section_value "$1" "$kind" >/dev/null && any=1; done
	[ "$any" -eq 0 ] && foundation_ieq "$2" skills && printf 'skills\n'
	return 0
}

# The sections of ai-artifacts.conf of one source kind (vendored, checkout or manifest), one per
# line, in name order. Usage: ai__sections_of KIND
ai__sections_of() {
	local file section
	file=$(ai__conf) || return 0
	while IFS= read -r section; do
		[ -n "$section" ] || continue
		ai_section_kinds "$section" | grep -qx "$1" && printf '%s\n' "$section"
	done < <(conf_sections "$file") | LC_ALL=C sort -f
}

# The vendored sources: the [sections] of ai-artifacts.conf Update-AiArtifacts copies into the
# artifacts root (a repository line, or no checkout or manifest line), one per line.
ai_vendored_sources() {
	ai__sections_of vendored
}

# The checkout sources: NAME<TAB>PATH per section with a `checkout PATH` line (PATH expanded), in
# name order.
ai_checkout_sources() {
	local name path
	while IFS= read -r name; do
		path=$(ai_section_value "$name" checkout) || continue
		printf '%s\t%s\n' "$name" "$(foundation_expand_path "$path")"
	done < <(ai__sections_of checkout)
}

# The manifest sources: NAME<TAB>FILE per section with a `manifest FILE` line (FILE expanded), in
# name order.
ai_manifest_sources() {
	local name path
	while IFS= read -r name; do
		path=$(ai_section_value "$name" manifest) || continue
		printf '%s\t%s\n' "$name" "$(foundation_expand_path "$path")"
	done < <(ai__sections_of manifest)
}

# The cache the manifest sources are cloned into, outside every repository:
# FOUNDATION_AI_MANIFEST_CACHE, else ${XDG_DATA_HOME:-~/.local/share}/foundation/ai-manifests.
ai_manifest_cache() {
	printf '%s' "${FOUNDATION_AI_MANIFEST_CACHE:-${XDG_DATA_HOME:-$HOME/.local/share}/foundation/ai-manifests}"
}

# The rows of a manifest file (docs/foundation/ai.md#manifest-sources: tab-separated name, kind,
# scope, source, ref, path, install; one header row; # comments), one record per line:
#   ROW<TAB>NAME<TAB>KIND<TAB>SCOPE<TAB>OWNER<TAB>REPO<TAB>REF<TAB>PATH<TAB>LINK<TAB>STRIP
#   WARN<TAB>MESSAGE        a row that is not valid (left out)
# LINK is the installed name (rename=, else NAME), STRIP 1 for strip-invocation-guard; KIND
# lowercased. Usage: ai_manifest_rows FILE
ai_manifest_rows() {
	[ -r "$1" ] || {
		printf 'WARN\tManifest %s cannot be read - its rows are skipped\n' "$1"
		return 0
	}
	awk -F'\t' -v file="${1##*/}" '
		function warn(text) { printf "WARN\t%s line %d: %s - skipped\n", file, FNR, text }
		{ sub(/\r$/, "") }
		/^[[:space:]]*(#|$)/ { next }
		!header { header = 1; if (tolower($1) == "name") next; warn("no header row (name, kind, scope, source, ref, path, install)") }
		{
			for (i = 1; i <= NF; i++) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i) }
			if (NF < 7) { warn("not 7 tab-separated columns"); next }
			name = $1; kind = tolower($2); scope = $3; source = $4; ref = $5; path = $6
			if (name !~ /^[A-Za-z0-9._-]+$/ || name ~ /^\.+$/) { warn("invalid name [" name "]"); next }
			if (kind !~ /^(skills|mods|rules|prompts|agents)$/) { warn("unknown kind [" $2 "]"); next }
			if (scope == "") { warn("empty scope"); next }
			url = source; sub(/\/+$/, "", url); sub(/\.git$/, "", url)
			if (url !~ /^https:\/\/github\.com\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/) { warn("source is not https://github.com/OWNER/REPO [" source "]"); next }
			split(url, parts, "/"); owner = parts[4]; repo = parts[5]
			if (tolower(ref) !~ /^[0-9a-f]+$/ || length(ref) != 40) { warn("ref is not a full commit SHA [" ref "]"); next }
			if (path == "" || path ~ /(^|\/)\.\.(\/|$)/ || path ~ /^\//) { warn("invalid path [" path "]"); next }
			n = split($7, words, /[[:space:]]+/)
			if (words[1] != "clone") { warn("install is not clone [" $7 "]"); next }
			link = name; strip = 0; bad = ""
			for (i = 2; i <= n; i++) {
				if (words[i] ~ /^rename=[A-Za-z0-9._-]+$/) { link = substr(words[i], 8) }
				else if (words[i] == "strip-invocation-guard") { strip = 1 }
				else if (words[i] != "") { bad = words[i] }
			}
			if (bad != "") { warn("unknown install option [" bad "]"); next }
			printf "ROW\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\n", name, kind, scope, owner, repo, tolower(ref), path, link, strip
		}' "$1"
}

# Does manifest SCOPE include the active profile? `*` does (with or without a profile), a
# comma-separated list of profile names does when it names the active one; `repo:NAME` never (those
# rows go into a repository, ai_manifest_repo_rows). Usage: ai_manifest_scope_applies SCOPE
ai_manifest_scope_applies() {
	local name
	local -a names
	[ "$1" = '*' ] && return 0
	case $1 in repo:*) return 1 ;; esac
	[ -n "${AI_PROFILE:-}" ] || return 1
	IFS=, read -r -a names <<<"$1"
	for name in "${names[@]}"; do
		name=$(foundation_trim "$name")
		[ "$name" = '*' ] && return 0
		foundation_ieq "$name" "$AI_PROFILE" && return 0
	done
	return 1
}

# The clone of OWNER/REPO at REF in the cache. Usage: ai_manifest_clone_dir OWNER REPO REF
ai_manifest_clone_dir() {
	printf '%s/%s/%s/%s' "$(ai_manifest_cache)" "$1" "$2" "$3"
}

# Does a manifest row need a derived copy: strip-invocation-guard, or a rename (Claude Code names
# a skill by the `name:` of its frontmatter, not its folder)? Usage: ai_manifest_derived NAME LINK STRIP
ai_manifest_derived() {
	[ "$3" = 1 ] || [ "$1" != "$2" ]
}

# The folder a manifest row is linked from: PATH inside the clone, or for a strip-invocation-guard
# or renamed row the derived copy <ref>.derived/LINK/.
# Usage: ai_manifest_item_dir OWNER REPO REF PATH NAME LINK STRIP
ai_manifest_item_dir() {
	local clone
	clone=$(ai_manifest_clone_dir "$1" "$2" "$3")
	if ai_manifest_derived "$5" "$6" "$7"; then
		printf '%s.derived/%s' "$clone" "$6"
	elif [ "$4" = . ]; then
		printf '%s' "$clone"
	else
		printf '%s/%s' "$clone" "${4%/}"
	fi
}

# Makes the derived copy of a strip-invocation-guard or renamed row when its clone exists and the
# copy does not: the item folder copied, then in the frontmatter of its SKILL.md the
# `disable-model-invocation` line taken out (STRIP 1) and `name:` set to LINK (a rename). A clone
# is never changed. Usage: ai_manifest_derive OWNER REPO REF PATH NAME LINK STRIP
ai_manifest_derive() {
	local clone source_dir target tmp rename=''
	clone=$(ai_manifest_clone_dir "$1" "$2" "$3")
	target=$(ai_manifest_item_dir "$1" "$2" "$3" "$4" "$5" "$6" "$7")
	[ -d "$target" ] && return 0
	ai_manifest_derived "$5" "$6" "$7" || return 0
	[ "$5" = "$6" ] || rename=$6
	source_dir=$clone
	[ "$4" = . ] || source_dir=$clone/${4%/}
	[ -d "$source_dir" ] || return 1
	mkdir -p "$(dirname "$target")" || return 1
	tmp=$(mktemp -d "$(dirname "$target")/.derive.XXXXXX") || return 1
	cp -R "$source_dir/." "$tmp/" || {
		rm -rf "$tmp"
		return 1
	}
	rm -rf "$tmp/.git"
	if [ -f "$tmp/SKILL.md" ]; then
		awk -v strip="$7" -v rename="$rename" '
			NR == 1 && /^---[[:space:]]*$/ { front = 1; print; next }
			front && /^---[[:space:]]*$/ { front = 0; print; next }
			front && strip == "1" && /^disable-model-invocation[[:space:]]*:/ { next }
			front && rename != "" && /^name[[:space:]]*:/ { print "name: " rename; next }
			{ print }' "$tmp/SKILL.md" >"$tmp/.SKILL.md.new" && mv "$tmp/.SKILL.md.new" "$tmp/SKILL.md"
	fi
	mv "$tmp" "$target"
}

# Clones URL at REF into CLONE through git (a temporary folder beside it, so a failed fetch leaves
# nothing behind): a shallow fetch of the commit, else a full clone; fails when REF is not reached.
# git's credential prompt is off, so a private or renamed upstream fails at once instead of waiting
# for an answer nobody sees. Usage: ai_manifest_fetch_clone URL REF CLONE
ai_manifest_fetch_clone() {
	local url=$1 ref=$2 clone=$3 tmp
	mkdir -p "$(dirname "$clone")" || return 1
	tmp=$(mktemp -d "$(dirname "$clone")/.fetch.XXXXXX") || return 1
	if ! { git -C "$tmp" init -q && GIT_TERMINAL_PROMPT=0 git -C "$tmp" fetch -q --depth 1 "$url" "$ref" && git -C "$tmp" -c advice.detachedHead=false checkout -q FETCH_HEAD; } >/dev/null 2>&1; then
		rm -rf "$tmp"
		tmp=$(mktemp -d "$(dirname "$clone")/.fetch.XXXXXX") || return 1
		if ! { GIT_TERMINAL_PROMPT=0 git clone -q --no-checkout "$url" "$tmp" && git -C "$tmp" -c advice.detachedHead=false checkout -q "$ref"; } >/dev/null 2>&1; then
			rm -rf "$tmp"
			return 1
		fi
	fi
	if [ "$(git -C "$tmp" rev-parse HEAD 2>/dev/null)" != "$ref" ]; then
		rm -rf "$tmp"
		return 1
	fi
	mv "$tmp" "$clone"
}

# Brings the cache in line with manifest FILE: every row whose scope includes the active profile
# (ai_manifest_scope_applies) or names a repository (repo:NAME) gets its pinned clone, fetched once
# (a clone already there is never fetched again), and its derived copy when it needs one. One
# record per line: FETCHING<TAB>OWNER/REPO@REF as a fetch starts (a large upstream takes a while),
# FETCHED<TAB>OWNER/REPO@REF once it is in, ROWS<TAB>COUNT at the end (the rows in scope), and
# WARN<TAB>MESSAGE for a row that could not be fetched or derived, or an invalid row. Fails when
# any row could not be brought in. Usage: ai_manifest_sync FILE
ai_manifest_sync() {
	local record row_name kind scope owner repo ref path link strip clone key seen=' ' rows=0 failed=0
	while IFS=$'\t' read -r record row_name kind scope owner repo ref path link strip; do
		if [ "$record" = WARN ]; then
			printf 'WARN\t%s\n' "$row_name"
			continue
		fi
		[ "$record" = ROW ] || continue
		case $scope in repo:?*) ;; *) ai_manifest_scope_applies "$scope" || continue ;; esac
		rows=$((rows + 1))
		clone=$(ai_manifest_clone_dir "$owner" "$repo" "$ref")
		key=$owner/$repo/$ref
		if [ ! -d "$clone" ]; then
			case $seen in *" $key "*) continue ;; esac
			seen+="$key "
			if ! command -v git >/dev/null 2>&1; then
				printf 'WARN\t%s: git is required to fetch %s/%s@%s\n' "$row_name" "$owner" "$repo" "${ref:0:7}"
				failed=1
				continue
			fi
			printf 'FETCHING\t%s/%s@%s\n' "$owner" "$repo" "${ref:0:7}"
			if ai_manifest_fetch_clone "https://github.com/$owner/$repo" "$ref" "$clone"; then
				printf 'FETCHED\t%s/%s@%s\n' "$owner" "$repo" "${ref:0:7}"
			else
				printf "WARN\tCould not fetch %s/%s@%s (row %s) - if it is private, sign in with 'gh auth login' and 'gh auth setup-git'\n" "$owner" "$repo" "${ref:0:7}" "$row_name"
				failed=1
				continue
			fi
		fi
		if ai_manifest_derived "$row_name" "$link" "$strip" && ! ai_manifest_derive "$owner" "$repo" "$ref" "$path" "$row_name" "$link" "$strip"; then
			printf 'WARN\t%s: no folder %s in %s/%s@%s to derive from\n' "$row_name" "$path" "$owner" "$repo" "${ref:0:7}"
			failed=1
		fi
	done < <(ai_manifest_rows "$1")
	printf 'ROWS\t%s\n' "$rows"
	[ "$failed" -eq 0 ]
}

# The repository-scoped manifest rows: REPO<TAB>REPOSITORY<TAB>LINK<TAB>DIR per `repo:NAME` skills
# row (DIR the folder to link, which may not exist yet), WARN<TAB>MESSAGE for one of another kind.
# Usage: ai_manifest_repo_rows
ai_manifest_repo_rows() {
	local name file record row_name kind scope owner repo ref path link strip
	while IFS=$'\t' read -r name file; do
		while IFS=$'\t' read -r record row_name kind scope owner repo ref path link strip; do
			[ "$record" = ROW ] || continue
			case $scope in repo:?*) ;; *) continue ;; esac
			if [ "$kind" != skills ]; then
				printf 'WARN\tManifest [%s] row %s: a repository-scoped row must be a skill (%s) - skipped\n' "$name" "$row_name" "$kind"
				continue
			fi
			printf 'REPO\t%s\t%s\t%s\n' "${scope#repo:}" "$link" "$(ai_manifest_item_dir "$owner" "$repo" "$ref" "$path" "$row_name" "$link" "$strip")"
		done < <(ai_manifest_rows "$file")
	done < <(ai_manifest_sources)
}

# The local folder of repository NAME: the folder of its line in FILE, the caller's
# repositories.conf (any group, compared without case), expanded; fails when no line names it or
# the line has no folder. Usage: ai_repository_dir FILE NAME
ai_repository_dir() {
	local file=$1 group line repo rest last
	shift
	[ -r "$file" ] || return 1
	while IFS= read -r group; do
		while IFS= read -r line; do
			read -r repo _ rest <<<"$line"
			foundation_ieq "$repo" "$1" || continue
			last=${rest##*[[:space:]]}
			if [ -n "$rest" ] && foundation_ieq "$last" shallow; then
				rest=${rest%"$last"}
				rest=$(foundation_trim "$rest")
			fi
			[ -n "$rest" ] || return 1
			foundation_expand_path "$rest"
			return 0
		done < <(conf_section "$file" "$group")
	done < <(conf_sections "$file")
	return 1
}

# What kind of source an entry of the roster comes from, for display: own, checkout, product
# (foundation), example, vendored or manifest. Usage: ai_source_kind SOURCE DIR
ai_source_kind() {
	case $2 in "$(ai_manifest_cache)"/*)
		printf 'manifest'
		return 0
		;;
	esac
	case $(foundation_lower "$1") in
		own) printf 'own' ;;
		foundation) printf 'product' ;;
		example) printf 'example' ;;
		*)
			case $2 in
				"$(ai_root)"/*) printf 'vendored' ;;
				*) printf 'checkout' ;;
			esac
			;;
	esac
}

# The source folders under the artifacts root read for KIND, one per line, each only when its
# folder exists: own, foundation, example, then the vendored sources in name order (spelled as
# on disk). Usage: ai_sources KIND
ai_sources() {
	local base allowed dir name fixed
	base=$(ai_root)/$(ai_kind_folder "$1") || return 1
	[ -d "$base" ] || return 0
	for fixed in own foundation example; do
		[ -d "$base/$fixed" ] && printf '%s\n' "$fixed"
	done
	allowed=$'\n'$(ai_vendored_sources | tr '[:upper:]' '[:lower:]')$'\n'
	for dir in "$base"/*/; do
		name=${dir%/}
		name=${name##*/}
		case $(foundation_lower "$name") in own | foundation | example) continue ;; esac
		case $allowed in *$'\n'"$(foundation_lower "$name")"$'\n'*) printf '%s\n' "$name" ;; esac
	done | LC_ALL=C sort -f
}

# The items of KIND directly under FOLDER as SOURCE<TAB>ITEM<TAB>DIR lines, in name order; with
# NESTED, a skills folder that is no item is looked into once (a category level).
# Usage: ai__folder_items KIND SOURCE FOLDER [NESTED]
ai__folder_items() {
	local kind=$1 source=$2 dir inner
	[ -d "$3" ] || return 0
	for dir in "$3"/*/; do
		dir=${dir%/}
		[ -d "$dir" ] || continue
		if ai_is_item "$kind" "$dir"; then
			printf '%s\t%s\t%s\n' "$source" "${dir##*/}" "$dir"
		elif [ -n "${4:-}" ] && [ "$kind" = skills ]; then
			for inner in "$dir"/*/; do
				inner=${inner%/}
				ai_is_item "$kind" "$inner" && printf '%s\t%s\t%s\n' "$source" "${inner##*/}" "$inner"
			done
		fi
	done
}

# Every candidate item of KIND in precedence order, before the exclude and include lines and the
# name clash: SOURCE<TAB>ITEM<TAB>DIR, or WARN<TAB>MESSAGE. own, the checkout sources (each folder
# of the section's KIND line, `skills skills` without one), foundation, example and the vendored
# sources, then the manifest rows whose scope includes the active profile (SOURCE is the owner of
# the row's upstream repository, ITEM its installed name). Usage: ai__candidates KIND
ai__candidates() {
	local kind=$1 base source name path folder dir file record row_name row_kind scope owner repo ref row_path link strip
	base=$(ai_root)/$(ai_kind_folder "$kind") || return 1
	ai__folder_items "$kind" own "$base/own"
	while IFS=$'\t' read -r name path; do
		[ -n "$name" ] || continue
		if [ ! -d "$path" ]; then
			printf 'WARN\tCheckout source [%s]: %s is not a folder on this machine - skipped\n' "$name" "$path"
			continue
		fi
		while IFS= read -r folder; do
			[ -n "$folder" ] || continue
			dir=$path
			[ "$folder" = . ] || dir=$path/$folder
			ai__folder_items "$kind" "$name" "$dir" nested
		done < <(ai_section_folders "$name" "$kind")
	done < <(ai_checkout_sources)
	while IFS= read -r source; do
		[ -n "$source" ] && [ "$source" != own ] && ai__folder_items "$kind" "$source" "$base/$source"
	done < <(ai_sources "$kind")
	while IFS=$'\t' read -r name file; do
		[ -n "$name" ] || continue
		while IFS=$'\t' read -r record row_name row_kind scope owner repo ref row_path link strip; do
			if [ "$record" = WARN ]; then
				# Said once per run, in the skills pass, not once per kind.
				[ "$kind" = skills ] && printf 'WARN\tManifest [%s]: %s\n' "$name" "$row_name"
				continue
			fi
			[ "$record" = ROW ] && [ "$row_kind" = "$kind" ] || continue
			ai_manifest_scope_applies "$scope" || continue
			dir=$(ai_manifest_item_dir "$owner" "$repo" "$ref" "$row_path" "$row_name" "$link" "$strip")
			if [ ! -d "$dir" ]; then
				printf 'WARN\tManifest [%s] row %s (%s/%s@%s) is not fetched yet - run Update-AiArtifacts %s\n' "$name" "$row_name" "$owner" "$repo" "${ref:0:7}" "$name"
				continue
			fi
			ai_is_item "$kind" "$dir" || {
				printf 'WARN\tManifest [%s] row %s: %s holds no %s item - skipped\n' "$name" "$row_name" "$row_path" "${kind%s}"
				continue
			}
			printf '%s\t%s\t%s\n' "$owner" "$link" "$dir"
		done < <(ai_manifest_rows "$file")
	done < <(ai_manifest_sources)
}

# The roster of KIND: SOURCE<TAB>ITEM<TAB>DIR per item deployed, in ai__candidates order, the
# `exclude` lines and the active profile's include and exclude lines applied; the first source wins
# an item name two carry, and the loser prints DUPLICATE<TAB>ITEM<TAB>DIR<TAB>KEPT-SOURCE<TAB>SOURCE.
# A configuration problem prints WARN<TAB>MESSAGE. Usage: ai_roster KIND
ai_roster() {
	local kind excludes includes source dir item seen=$'\n' kept lower lsource
	kind=$(foundation_lower "$1")
	ai_kind_folder "$kind" >/dev/null || return 1
	excludes=$'\n'$(ai_excludes)$'\n'
	includes=$(ai_includes | awk -F/ -v k="$kind" '$1 == k')
	[ -z "$includes" ] || includes=$'\n'$includes$'\n'
	while IFS=$'\t' read -r source item dir; do
		if [ "$source" = WARN ]; then
			printf 'WARN\t%s\n' "$item"
			continue
		fi
		lower=$(foundation_lower "$item")
		lsource=$(foundation_lower "$source")
		case $excludes in
			*$'\n'"$kind/$lower"$'\n'* | *$'\n'"$kind/$lsource/$lower"$'\n'*) continue ;;
		esac
		if [ -n "$includes" ]; then
			case $includes in
				*$'\n'"$kind/$lower"$'\n'* | *$'\n'"$kind/$lsource/$lower"$'\n'*) ;;
				*) continue ;;
			esac
		fi
		# seen holds one ITEM<TAB>SOURCE line per winner, lowercased item.
		case $seen in
			*$'\n'"$lower"$'\t'*)
				kept=${seen#*$'\n'"$lower"$'\t'}
				printf 'DUPLICATE\t%s\t%s\t%s\t%s\n' "$item" "$dir" "${kept%%$'\n'*}" "$source"
				continue
				;;
		esac
		seen+="$lower"$'\t'"$source"$'\n'
		printf '%s\t%s\t%s\n' "$source" "$item" "$dir"
	done < <(ai__candidates "$kind")
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
			while IFS=$'\t' read -r source item dir kept _; do
				if [ "$source" = WARN ]; then
					printf 'WARN\t%s\n' "$item"
					continue
				fi
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
