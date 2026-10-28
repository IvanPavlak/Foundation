#!/usr/bin/env bats
# The Unix reference pages that list what the code does, checked against the code, in the style of
# doclinks.bats: docs/foundation/backups.md names every category and fixed key prefix of a backup_item
# call under Unix/, and docs/foundation/software-list.md lists exactly the entries of Unix/Brewfile.

load helpers

setup() {
	setup_foundation
	DOCS=$(dirname "$UNIX_DIR")/docs
}

# CATEGORY<TAB>KEY of every backup_item call under DIR outside the test suites and the logs; a call in a comment
# (the `#` comes before it on the line) is not a call. KEY is the second argument as written, quotes
# dropped. Usage: backup_calls DIR
backup_calls() {
	grep -rhE '^[^#]*backup_item [A-Za-z]' "$1" --exclude-dir=tests --exclude-dir=logs |
		sed -E 's/.*backup_item ([A-Za-z]+) "?([^" ]*).*/\1	\2/' | LC_ALL=C sort -u
}

# The fixed prefix of a backup key as written: up to the first `$` or `.`, empty when it starts
# with an expansion. Usage: key_prefix KEY
key_prefix() {
	local key=${1%%\$*}
	printf '%s' "${key%%.*}"
}

@test "every backup_item category and fixed key prefix under Unix appears in docs/foundation/backups.md" {
	page=$DOCS/foundation/backups.md
	[ -f "$page" ]
	calls=$(backup_calls "$UNIX_DIR")
	# The scan finds the writers it should (a broken pattern would pass on nothing).
	[[ $calls == *$'Config\tobsidian.json'* ]]
	[[ $calls == *$'SymbolicLinks\tAiArtifacts.'* ]]
	missing=''
	while IFS=$'\t' read -r category key; do
		grep -qF "| \`$category\` |" "$page" || missing="$missing category $category"$'\n'
		prefix=$(key_prefix "$key")
		[ -z "$prefix" ] || grep -qF "\`$prefix" "$page" || missing="$missing key $category/$key"$'\n'
	done <<<"$calls"
	[ -z "$missing" ] || {
		printf 'not in docs/foundation/backups.md:\n%s' "$missing"
		return 1
	}
}

@test "the checker itself: a call in a comment is not a call, a quoted key keeps its prefix" {
	mkdir -p "$BATS_TEST_TMPDIR/unix/bin" "$BATS_TEST_TMPDIR/unix/tests"
	cat >"$BATS_TEST_TMPDIR/unix/bin/writer" <<'SH'
# Usage: backup_item CATEGORY KEY PATH
	folder=$(backup_item SymbolicLinks "Thing.$name" "$path") || exit 1
backup_item Config "$(conf__backup_key "$target")" "$target" >/dev/null
SH
	printf 'backup_item Fixture Key x\n' >"$BATS_TEST_TMPDIR/unix/tests/suite.bats"
	run backup_calls "$BATS_TEST_TMPDIR/unix"
	[ "$output" = $'Config\t$(conf__backup_key\nSymbolicLinks\tThing.$name' ]
	[ "$(key_prefix 'Thing.$name')" = Thing ]
	[ -z "$(key_prefix '$(conf__backup_key')" ]
	[ "$(key_prefix storage.json)" = storage ]
}

# KIND NAME of every entry of a Brewfile (tap, brew, cask, mas; the name between the first quotes).
# Usage: brewfile_entries FILE
brewfile_entries() {
	awk '$1 ~ /^(tap|brew|cask|mas)$/ && match($0, /"[^"]*"/) { print $1, substr($0, RSTART + 1, RLENGTH - 2) }' "$1" | LC_ALL=C sort
}

# KIND NAME of every row of the base Brewfile table of the software page: the rows under
# `## The base Brewfile` whose first cell is code. Usage: page_entries FILE
page_entries() {
	awk -F'|' '
		/^## / { section = ($0 == "## The base Brewfile") }
		section && /^\| `/ {
			name = $2; gsub(/`/, "", name); gsub(/^ +| +$/, "", name)
			kind = $3; gsub(/^ +| +$/, "", kind)
			print kind, name
		}' "$1" | LC_ALL=C sort
}

@test "docs/foundation/software-list.md lists exactly the entries of Unix/Brewfile" {
	brewfile=$(brewfile_entries "$UNIX_DIR/Brewfile")
	page=$(page_entries "$DOCS/foundation/software-list.md")
	[ -n "$brewfile" ]
	[ "$brewfile" = "$page" ] || {
		printf 'Unix/Brewfile only:\n%s\nthe page only:\n%s\n' \
			"$(comm -23 <(printf '%s\n' "$brewfile") <(printf '%s\n' "$page"))" \
			"$(comm -13 <(printf '%s\n' "$brewfile") <(printf '%s\n' "$page"))"
		return 1
	}
}

@test "the Brewfile and page readers: comments, mas names with spaces, other sections" {
	cat >"$BATS_TEST_TMPDIR/Brewfile" <<'RUBY'
# brew "commented"
tap "some/tap"
brew "tool"                       # a comment with "quotes"
mas "Some App: Two", id: 123
RUBY
	[ "$(brewfile_entries "$BATS_TEST_TMPDIR/Brewfile")" = $'brew tool\nmas Some App: Two\ntap some/tap' ]
	cat >"$BATS_TEST_TMPDIR/page.md" <<'MD'
## The base Brewfile

| Entry | Kind | Why |
| ----- | ---- | --- |
| `tool` | brew | needed |

## Your own packages

| `other` | cask | not the base table |
MD
	[ "$(page_entries "$BATS_TEST_TMPDIR/page.md")" = 'brew tool' ]
}
