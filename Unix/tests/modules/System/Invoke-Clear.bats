#!/usr/bin/env bats
# Invoke-Clear against a stub clear: the screen is cleared unless greeting.conf says `clear off`,
# and the escape sequence stands in when `clear` fails.

load ../../helpers

setup() {
	setup_foundation
	use_empty_config
	stub_tool clear 'exit 0'
	cmd=$UNIX_DIR/modules/System/bin/Invoke-Clear
}

cleared() { grep -q '^clear' "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null; }

@test "clears by default and with clear on" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	cleared
	: >"$BATS_TEST_TMPDIR/tool.log"
	echo 'clear on' >"$FOUNDATION_CONFIG_DIR/greeting.conf"
	run "${BASH:-bash}" "$cmd"
	cleared
}

@test "clear off (a later line wins) leaves the screen alone" {
	printf '%s\n' 'clear on' 'clear off' >"$FOUNDATION_CONFIG_DIR/greeting.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	! cleared || false
}

@test "a failing clear falls back to the escape sequence" {
	stub_tool clear 'exit 1'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$output" = $'\033[H\033[2J\033[3J' ]
}
