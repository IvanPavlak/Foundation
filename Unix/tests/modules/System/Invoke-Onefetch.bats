#!/usr/bin/env bats
# Invoke-Onefetch against an onefetch stand-in: the panel is drawn only inside a git repository
# with greeting.conf onefetch on, restyled (true colors, separator, continuation padding);
# --measure counts its rows, and every silent case (off, outside a repository, failure, no onefetch)
# draws nothing; --arguments replaces the configured arguments, --always runs what a typed onefetch
# would, and the OnefetchStyle startup skip leaves the output as onefetch printed it.

load ../../helpers

setup() {
	setup_foundation
	# A two-line panel: a logo column, one field with onefetch's colored colon, one continuation line.
	stub_tool onefetch "printf 'LOGO  \033[94mProject\033[94m:\033[0m Demo\nLOGO  value2\n'"
	[ "$(command -v onefetch)" = "$BATS_TEST_TMPDIR/tools/onefetch" ]
	repo=$BATS_TEST_TMPDIR/repo
	mkdir -p "$repo/.git" "$repo/src" "$BATS_TEST_TMPDIR/plain"
	cmd=$UNIX_DIR/modules/System/bin/Invoke-Onefetch
}

called() {
	grep -q '^onefetch' "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null
}

@test "inside a repository onefetch runs with the greeting.conf arguments and the panel is restyled" {
	run "${BASH:-bash}" "$cmd" --path "$repo/src"
	[ "$status" -eq 0 ]
	grep -qx 'onefetch --text-colors 12 9 9 12 9 15 --nerd-fonts --no-bold' "$BATS_TEST_TMPDIR/tool.log"
	[ "${#lines[@]}" -eq 2 ]
	# Index 12 became its true color, the colon became the configured separator.
	[[ ${lines[0]} == *$'\033[38;2;30;144;255mProject'* ]]
	[[ ${lines[0]} == *" -> "* ]]
	[[ ${lines[0]} != *":"* ]]
	# The continuation line is padded by the separator's extra width at the value column.
	[ "${lines[1]}" = "LOGO    value2" ]
}

@test "--measure prints the panel's height in rows" {
	run "${BASH:-bash}" "$cmd" --measure --path "$repo"
	[ "$status" -eq 0 ]
	[ "$output" = 2 ]
}

@test "outside a repository nothing is drawn and onefetch never runs; --measure prints 0" {
	run "${BASH:-bash}" "$cmd" --path "$BATS_TEST_TMPDIR/plain"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	run "${BASH:-bash}" "$cmd" --measure --path "$BATS_TEST_TMPDIR/plain"
	[ "$status" -eq 0 ]
	[ "$output" = 0 ]
	! called || false
}

@test "a missing directory is silent" {
	run "${BASH:-bash}" "$cmd" --measure --path "$BATS_TEST_TMPDIR/missing"
	[ "$status" -eq 0 ]
	[ "$output" = 0 ]
	! called || false
}

@test "onefetch off in greeting.conf (a later line wins) draws nothing" {
	copy_fixture_config
	echo 'onefetch off' >>"$FOUNDATION_CONFIG_DIR/greeting.conf"
	run "${BASH:-bash}" "$cmd" --path "$repo"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	! called || false
}

@test "without an onefetch line nothing draws, as WinuX's base Onefetch.Enabled is off" {
	copy_fixture_config
	grep -v '^onefetch ' "$FIXTURE_CONFIG/greeting.conf" >"$FOUNDATION_CONFIG_DIR/greeting.conf"
	run "${BASH:-bash}" "$cmd" --measure --path "$repo"
	[ "$status" -eq 0 ]
	[ "$output" = 0 ]
	use_empty_config
	run "${BASH:-bash}" "$cmd" --path "$repo"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	! called || false
}

@test "keys are case-insensitive, as conf_value reads them" {
	copy_fixture_config
	echo 'OneFetch off' >>"$FOUNDATION_CONFIG_DIR/greeting.conf"
	run "${BASH:-bash}" "$cmd" --path "$repo"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	! called || false
	copy_fixture_config
	echo 'ONEFETCH-COLOR 12 38;2;1;2;3' >>"$FOUNDATION_CONFIG_DIR/greeting.conf"
	run "${BASH:-bash}" "$cmd" --path "$repo"
	[[ ${lines[0]} == *$'\033[38;2;1;2;3mProject'* ]]
}

@test "the last onefetch-color line for an index wins, so an overlay line overrides the base" {
	copy_fixture_config
	echo 'onefetch-color 12 38;2;0;128;0' >"$FOUNDATION_CONFIG_DIR/greeting.local.conf"
	run "${BASH:-bash}" "$cmd" --path "$repo"
	[ "$status" -eq 0 ]
	[[ ${lines[0]} == *$'\033[38;2;0;128;0mProject'* ]]
	[[ ${lines[0]} != *'38;2;30;144;255'* ]]
}

@test "--measure with onefetch-auto-fit off prints 0 without running onefetch, the panel still draws" {
	copy_fixture_config
	echo 'onefetch-auto-fit off' >>"$FOUNDATION_CONFIG_DIR/greeting.conf"
	run "${BASH:-bash}" "$cmd" --measure --path "$repo"
	[ "$output" = 0 ]
	! called || false
	run "${BASH:-bash}" "$cmd" --path "$repo"
	[ "${#lines[@]}" -eq 2 ]
	called
}

@test "a failing or silent onefetch (an empty repository) draws nothing" {
	stub_tool onefetch 'exit 1'
	run "${BASH:-bash}" "$cmd" --path "$repo"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	run "${BASH:-bash}" "$cmd" --measure --path "$repo"
	[ "$output" = 0 ]
	stub_tool onefetch 'exit 0'
	run "${BASH:-bash}" "$cmd" --measure --path "$repo"
	[ "$output" = 0 ]
}

@test "without a separator line the colon stays" {
	copy_fixture_config
	grep -v '^onefetch-separator' "$FIXTURE_CONFIG/greeting.conf" >"$FOUNDATION_CONFIG_DIR/greeting.conf"
	run "${BASH:-bash}" "$cmd" --path "$repo"
	[ "$status" -eq 0 ]
	[[ ${lines[0]} == *":"* ]]
	[ "${lines[1]}" = "LOGO  value2" ]
}

@test "an unknown argument fails before onefetch runs" {
	run "${BASH:-bash}" "$cmd" --bogus
	[ "$status" -ne 0 ]
	! called || false
}

@test "without onefetch nothing is drawn and --measure prints 0" {
	export FOUNDATION_ONEFETCH=$BATS_TEST_TMPDIR/no-onefetch
	run "${BASH:-bash}" "$cmd" --path "$repo"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	run "${BASH:-bash}" "$cmd" --measure --path "$repo"
	[ "$status" -eq 0 ]
	[ "$output" = 0 ]
	run "${BASH:-bash}" "$cmd" --always --path "$repo"
	[ "$status" -ne 0 ]
}

@test "--arguments replaces onefetch-arguments: the rest of the line, or one quoted string" {
	run "${BASH:-bash}" "$cmd" --path "$repo" --arguments --no-art --no-bold
	[ "$status" -eq 0 ]
	grep -qx 'onefetch --no-art --no-bold' "$BATS_TEST_TMPDIR/tool.log"
	[[ ${lines[0]} == *" -> "* ]]
	: >"$BATS_TEST_TMPDIR/tool.log"
	run "${BASH:-bash}" "$cmd" --path "$repo" -Arguments "--no-art --no-color-palette"
	grep -qx 'onefetch --no-art --no-color-palette' "$BATS_TEST_TMPDIR/tool.log"
}

@test "the words after --arguments are onefetch's, never this command's flags" {
	run "${BASH:-bash}" "$cmd" --path "$repo" --arguments --measure
	[ "$status" -eq 0 ]
	grep -qx 'onefetch --measure' "$BATS_TEST_TMPDIR/tool.log"
	[ "${#lines[@]}" -eq 2 ]
}

@test "--always runs with onefetch off and outside a repository, and onefetch's failure comes through" {
	copy_fixture_config
	echo 'onefetch off' >>"$FOUNDATION_CONFIG_DIR/greeting.conf"
	run "${BASH:-bash}" "$cmd" --always --path "$repo"
	[ "$status" -eq 0 ]
	[ "${#lines[@]}" -eq 2 ]
	run "${BASH:-bash}" "$cmd" --always --path "$BATS_TEST_TMPDIR/plain"
	[ "${#lines[@]}" -eq 2 ]
	stub_tool onefetch 'echo "not a repository" >&2; exit 3'
	run "${BASH:-bash}" "$cmd" --always --path "$BATS_TEST_TMPDIR/plain"
	[ "$status" -eq 3 ]
	[[ $output == *"not a repository"* ]]
}

@test "FOUNDATION_STARTUP_SKIP naming OnefetchStyle, in any case, prints onefetch's output unstyled" {
	FOUNDATION_STARTUP_SKIP='Prompt onefetchstyle' run "${BASH:-bash}" "$cmd" --path "$repo"
	[ "$status" -eq 0 ]
	[[ ${lines[0]} == *$'\033[94mProject\033[94m:'* ]]
	[ "${lines[1]}" = "LOGO  value2" ]
}
