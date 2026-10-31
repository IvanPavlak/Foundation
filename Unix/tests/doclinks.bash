# Relative Markdown links and their anchors under docs/foundation - the Infrastructure-DocumentationLinks
# check of the Windows half, plus anchors. Load after helpers; used by doclinks.bats and guides.bats.

# The lines of a Markdown file outside code fences. A fence closes only with a run of at least as
# many backticks as opened it, so a five-backtick template may hold three-backtick blocks.
# Usage: doclinks_prose FILE
doclinks_prose() {
	awk '
		match($0, /^`{3,}/) {
			n = RLENGTH
			if (!fence) { fence = n; next }
			if (n >= fence && $0 ~ /^`+[[:space:]]*$/) { fence = 0; next }
		}
		!fence' "$1"
}

# The docsify slug of a heading: link markup reduced to its text, lower case, punctuation dropped,
# whitespace runs to hyphens. Usage: doclinks_slug TEXT
doclinks_slug() {
	printf '%s\n' "$1" | doclinks_slugs
}

# doclinks_slug for every line of stdin at once. Usage: ... | doclinks_slugs
doclinks_slugs() {
	sed -E 's/\[([^]]*)\]\([^)]*\)/\1/g' | tr '[:upper:]' '[:lower:]' |
		sed -E "s/<[^>]+>//g; s/[][\`'!\"#\$%&()*+,.\/:;<=>?@^{|}~]//g; s/^[[:space:]]+//; s/[[:space:]]+\$//; s/[[:space:]]+/-/g"
}

# The anchors of a Markdown file, one per line (code blocks skipped; a repeated slug gets -1, -2).
# Every heading goes through one doclinks_slugs pipeline: a pipeline per heading cost a few
# processes each, thousands per run. Usage: doclinks_anchors FILE
doclinks_anchors() {
	doclinks_prose "$1" | grep -E '^#+[[:space:]]' | sed -E 's/^#+//' | doclinks_slugs |
		awk '{ if ($0 in seen) printf "%s-%d\n", $0, ++seen[$0]; else { seen[$0] = 0; print } }'
}

# Every broken link of the Markdown files under DIR: FILE<TAB>TARGET<TAB>REASON. Checked: relative
# links and /-anchored ones (the docsify root, DOCS-ROOT), their file and, for a .md target, the
# anchor. Skipped: URLs, mail links, links inside code. Usage: doclinks_broken DIR DOCS-ROOT
doclinks_broken() {
	local dir=$1 root=$2 file target path anchor resolved
	# Each page's anchors are computed once and reused for every link into it: rebuilding them per
	# link (each heading's slug is a few processes) cost minutes on the 3-CPU CI runner.
	local -A anchor_cache=()
	while IFS= read -r file; do
		while IFS= read -r target; do
			case $target in http://* | https://* | mailto:* | '') continue ;; esac
			path=${target%%#*}
			anchor=''
			[ "$path" != "$target" ] && anchor=${target#*#}
			case $path in
				'') resolved=$file ;;
				/*) resolved=$root$path ;;
				*) resolved=${file%/*}/$path ;;
			esac
			if [ ! -e "$resolved" ]; then
				printf '%s\t%s\tmissing file\n' "$file" "$target"
				continue
			fi
			[ -n "$anchor" ] && [ "${resolved%.md}" != "$resolved" ] || continue
			# Read whole, never through grep -q: a reader that stops early breaks the writer's pipe,
			# and where SIGPIPE is ignored (the CI runner) that is a write error on stderr.
			[ -n "${anchor_cache[$resolved]+x}" ] || anchor_cache[$resolved]=$'\n'$(doclinks_anchors "$resolved")$'\n'
			case ${anchor_cache[$resolved]} in
				*$'\n'"$anchor"$'\n'*) ;;
				*) printf '%s\t%s\tmissing anchor\n' "$file" "$target" ;;
			esac
		done < <(doclinks_prose "$file" | sed -E 's/`[^`]*`//g' | grep -oE '\]\([^) ]+\)' | sed -E 's/^\]\(//; s/\)$//')
	done < <(find "$dir" -name '*.md' | sort)
}
