#!/usr/bin/env bats
# Infrastructure-ConfigurationGuides analog: every command line of every manifest has exactly one
# configuration guide under docs/unix/guides (docs/unix/guides/README.md has the rules and
# templates), listed in its folder's index; a FULL guide keeps the template's headings and decision
# shape and names every Unix/config file the command reads; a STUB carries the sentinel sentence and
# belongs to a command that reads none. The Foundation sidebar (docs/unix/_sidebar.md) lists every
# module page, every guide index and the macOS Configurator page.

load helpers
load guides
load doclinks

setup() {
	setup_foundation
	GUIDES=$(dirname "$UNIX_DIR")/docs/unix/guides
	SENTINEL='This command reads no `Unix/config` files. There is nothing to configure.'
}

# Fails with the collected problems, one per line, when there are any.
report() {
	[ -z "$problems" ] || {
		printf '%s\n' "$problems"
		return 1
	}
}

@test "every command has its guide, and every guide belongs to a command" {
	problems=''
	expected=$(guides_commands | cut -f4 | sort)
	while IFS= read -r guide; do
		[ -f "$GUIDES/$guide" ] || problems+="missing guide: $guide"$'\n'
	done <<<"$expected"
	actual=$(cd "$GUIDES" && find . -name '*.md' ! -name README.md | sed 's#^\./##' | sort)
	while IFS= read -r guide; do
		[ -n "$guide" ] || continue
		grep -qxF -- "$guide" <<<"$expected" || problems+="orphan guide (no command line): $guide"$'\n'
	done <<<"$actual"
	report
}

@test "every guide folder has an index listing each of its guides, and the guides home lists every folder" {
	problems=''
	while IFS=$'\t' read -r _ name _ guide; do
		folder=$(dirname "$guide")
		index=$GUIDES/$folder/README.md
		if [ ! -f "$index" ]; then
			problems+="missing index: $folder/README.md"$'\n'
			continue
		fi
		grep -qF -- "]($name.md)" "$index" || problems+="$folder/README.md does not link $name.md"$'\n'
		grep -qF -- "]($folder/README.md)" "$GUIDES/README.md" || problems+="guides/README.md does not link $folder/README.md"$'\n'
	done < <(guides_commands)
	report
}

@test "the Foundation sidebar lists every module page, every guide index and the configurator page" {
	# Infrastructure-ConfigurationGuides on Windows: the sidebar lists every module guide index and
	# the configurator page exists and is registered. The Unix pages have their own sidebar, which
	# docsify shows on every page under /unix/; the shared docs/_sidebar.md stays WinuX's.
	problems=''
	docs=$(dirname "$UNIX_DIR")/docs
	sidebar=$docs/unix/_sidebar.md
	[ -f "$sidebar" ] || problems+="missing docs/unix/_sidebar.md"$'\n'
	[ -f "$docs/unix/macos-configurator.md" ] || problems+="missing docs/unix/macos-configurator.md"$'\n'
	pages=(unix/macos-configurator.md)
	while IFS= read -r dir; do
		module=$(foundation_module_name "$dir")
		pages+=("$(foundation_module_page "$module" | sed 's#^docs/##')" "unix/guides/$(foundation_lower "$module")/README.md")
	done < <(foundation_module_dirs)
	for page in "${pages[@]}"; do
		grep -qF -- "](/$page)" "$sidebar" 2>/dev/null || problems+="docs/unix/_sidebar.md does not list /$page"$'\n'
	done
	report
}

@test "a FULL guide keeps the template headings and decision shape; a STUB is the stub template" {
	problems=''
	while IFS=$'\t' read -r _ name _ guide; do
		file=$GUIDES/$guide
		[ -f "$file" ] || continue
		headings=$(doclinks_prose "$file" | grep -E '^#{1,2} ' | sed -E 's/^## Step [0-9]+:.*/## Step/' | uniq | paste -sd'|' -)
		if grep -qF -- "$SENTINEL" "$file"; then
			[ "$headings" = "# $name|## Configuration Keys|## Usage|## Related" ] ||
				problems+="$guide: STUB headings are [$headings]"$'\n'
			continue
		fi
		[ "$headings" = "# $name|## Configuration Keys|## Decisions|## Where to Put Values|## Steps Overview|## Step|## Verification|## Complete Example|## Related" ] ||
			problems+="$guide: FULL headings are [$headings]"$'\n'
		# Each decision: a numbered question, then exactly Options, Default, More detail.
		shape=$(awk '
			/^## Decisions/ { inside = 1; next }
			/^## / { inside = 0 }
			inside && /^[0-9]+\. / { if (n) print kids; n++; kids = ""; next }
			inside && /^    - [A-Za-z ]+:/ { k = $0; sub(/^    - /, "", k); sub(/:.*/, "", k); kids = kids k "," }
			END { if (n) print kids; else print "none" }' "$file" | sort -u | paste -sd'|' -)
		[ "$shape" = "Options,Default,More detail," ] || problems+="$guide: decision bullets are [$shape]"$'\n'
	done < <(guides_commands)
	report
}

@test "a guide names every Unix/config file its command reads; a STUB's command reads none" {
	problems=''
	while IFS=$'\t' read -r _ name exe guide; do
		file=$GUIDES/$guide
		[ -f "$file" ] || continue
		files=$(command_config_files "$exe")
		if grep -qF -- "$SENTINEL" "$file"; then
			[ -z "$files" ] || problems+="$guide: STUB, but $name reads $(printf '%s' "$files" | paste -sd' ' -)"$'\n'
			continue
		fi
		table=$(awk '/^## Configuration Keys/ { on = 1; next } /^## / { on = 0 } on' "$file")
		for conf in $files; do
			grep -qF -- "\`$conf\`" <<<"$table" || problems+="$guide: Configuration Keys lacks $conf"$'\n'
		done
	done < <(guides_commands)
	report
}

@test "the guides use no em-dash" {
	run grep -rln $'\xe2\x80\x94' "$GUIDES"
	[ -z "$output" ] || {
		printf 'em-dash in: %s\n' "$output"
		return 1
	}
}
