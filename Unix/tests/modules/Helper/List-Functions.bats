#!/usr/bin/env bats
# List-Functions: the Windows layout (module borders, name, description, Key => value lines, the
# total border), filters, the category and function selections (by name or menu number), names
# only, the three-way discrepancy check with --quiet and the list-functions.conf exclusions and
# colours.

load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_LOGGING=off COLUMNS=60
	cmd=$UNIX_DIR/modules/Helper/bin/List-Functions
}

@test "a filtered listing: module border, name, description, Key => value lines and the total border" {
	run "${BASH:-bash}" "$cmd" Countdown
	[ "$status" -eq 0 ]
	[[ ${lines[0]} == "="*" [Helper] "*"=" ]]
	[ "${#lines[0]}" -eq 60 ]
	[ "${lines[1]}" = " Countdown" ]
	[[ ${lines[3]} == "    Usage => Countdown SECONDS"* ]]
	[[ ${lines[${#lines[@]} - 1]} == *" [Total function count => 1] "* ]]
	# A filtered listing carries no discrepancy report.
	[[ $output != *"Discrepancy Report"* ]]
}

@test "patterns and --module filter; --names prints names only" {
	run "${BASH:-bash}" "$cmd" 'kill*' --names
	[ "$output" = Kill-All ]
	run "${BASH:-bash}" "$cmd" --module git --names
	[[ $output == *GitStatus* ]]
	[[ $output != *Kill-All* ]]
}

@test "--category and --function take names, each with its own borders" {
	run "${BASH:-bash}" "$cmd" --category logging
	[ "$status" -eq 0 ]
	[[ ${lines[0]} == *" [Logging] "* ]]
	[[ $output == *" [Function count => 4] "* ]]
	run "${BASH:-bash}" "$cmd" --function countdown
	[[ ${lines[0]} == *" [Helper] "* ]]
	[ "${lines[1]}" = " Countdown" ]
	[[ ${lines[${#lines[@]} - 1]} =~ ^=+$ ]]
	run "${BASH:-bash}" "$cmd" --category NoSuchModule
	[[ $output == *"No [NoSuchModule] to list"* ]]
}

@test "--category and --function take a menu number too, as -Category 1 does on Windows" {
	run "${BASH:-bash}" "$cmd" --category 1
	[ "$status" -eq 0 ]
	[[ ${lines[0]} =~ \ \[[A-Za-z]+\]\  ]]
	[[ $output == *" [Function count => "* ]]
	[[ $output != *"No [1] to list"* ]]
	run "${BASH:-bash}" "$cmd" --function 1
	[ "$status" -eq 0 ]
	[ -n "${lines[1]}" ]
	[[ $output != *"No [1] to list"* ]]
}

@test "--list-discrepancies passes on the committed tree; --quiet keeps it silent" {
	run "${BASH:-bash}" "$cmd" --list-discrepancies
	[ "$status" -eq 0 ]
	[[ $output == *"No discrepancies"* ]]
	run "${BASH:-bash}" "$cmd" --list-discrepancies --quiet
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "a discrepancy is reported under its border unless list-functions.conf excludes the name" {
	copy_fixture_config
	# A copy of the pages without the Countdown entry: Countdown becomes undocumented.
	export DOTFILES_ROOT=$BATS_TEST_TMPDIR/root
	mkdir -p "$DOTFILES_ROOT/docs"
	cp -R "$UNIX_DIR/../docs/unix" "$DOTFILES_ROOT/docs/unix"
	awk '/^## \[Countdown\]/ { skip = 1; next } skip && /^## / { skip = 0 } !skip' "$UNIX_DIR/../docs/unix/modules/Helper.md" >"$DOTFILES_ROOT/docs/unix/modules/Helper.md"
	run "${BASH:-bash}" "$cmd" --list-discrepancies
	[ "$status" -eq 1 ]
	[[ $output == *" [Discrepancy Report] "* ]]
	[[ $output == *"[Helper] undocumented command => Countdown"* ]]
	# The full listing appends the same report.
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"undocumented command => Countdown"* ]]
	printf 'exclude Countdown\n' >"$FOUNDATION_CONFIG_DIR/list-functions.conf"
	run "${BASH:-bash}" "$cmd" --list-discrepancies --quiet
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "a page whose entries are not alphabetical is a discrepancy" {
	# A copy of the pages with the Countdown entry moved to the end of the Helper page.
	export DOTFILES_ROOT=$BATS_TEST_TMPDIR/root
	mkdir -p "$DOTFILES_ROOT/docs"
	cp -R "$UNIX_DIR/../docs/unix" "$DOTFILES_ROOT/docs/unix"
	awk '/^## \[Countdown\]/ { moving = 1 } moving && /^## / && !/^## \[Countdown\]/ { moving = 0 }
		moving { block = block $0 "\n"; next } { print } END { printf "\n%s", block }' \
		"$UNIX_DIR/../docs/unix/modules/Helper.md" >"$DOTFILES_ROOT/docs/unix/modules/Helper.md"
	last=$(grep -oE '^## \[[^]]+\]' "$UNIX_DIR/../docs/unix/modules/Helper.md" | tail -1 | sed 's/^## \[//; s/\]$//')
	run "${BASH:-bash}" "$cmd" --list-discrepancies
	[ "$status" -eq 1 ]
	[[ $output == *"[Helper] Countdown belongs before $last (a page lists its entries alphabetically)"* ]]
	# Only the moved entry is out of place.
	[ "$(grep -c 'belongs before' <<<"$output")" -eq 1 ]
}

@test "colours come from list-functions.conf when the output is coloured" {
	copy_fixture_config
	printf 'border Magenta\nfunction-name 208\n' >"$FOUNDATION_CONFIG_DIR/list-functions.conf"
	LOG_FORCE_COLOR=1 run "${BASH:-bash}" "$cmd" Countdown
	[[ ${lines[0]} == $'\033[35m'*"[Helper]"* ]]
	[[ $output == *$'\033[38;5;208m Countdown'* ]]
}

@test "an empty --function name shows the menu instead of failing on []" {
	printf 'countdown\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd" --function ""
	[[ $output != *"No [] to list"* ]]
	[[ $output == *" Countdown"* ]]
}

@test "a Markdown link in a bullet prints as its text" {
	# A copy of the pages whose Countdown entry links a page in its description and its usage.
	export DOTFILES_ROOT=$BATS_TEST_TMPDIR/root COLUMNS=400
	mkdir -p "$DOTFILES_ROOT/docs"
	cp -R "$UNIX_DIR/../docs/unix" "$DOTFILES_ROOT/docs/unix"
	awk '/^## \[Countdown\]/ { entry = 1 }
		entry && /^- \*\*Description:\*\*/ { $0 = $0 " See [Some Page](../some-page.md#an-anchor) and [`Other`](https://example.invalid)." }
		entry && /^- \*\*Usage:\*\*/ { $0 = $0 ", [Countdown 5](#countdown)"; entry = 0 }
		{ print }' "$UNIX_DIR/../docs/unix/modules/Helper.md" >"$DOTFILES_ROOT/docs/unix/modules/Helper.md"
	run "${BASH:-bash}" "$cmd" Countdown
	[ "$status" -eq 0 ]
	[[ $output == *"See Some Page and Other."* ]]
	[[ $output == *", Countdown 5"* ]]
	[[ $output != *"]("* ]]
}
