#!/usr/bin/env bats
# Move-Windows against the AeroSpace stand-in: every window (or the ones whose app or title
# matches) goes to the target desktop (1-100, default 1, --current the focused one), windows already
# there stay, and focus ends on the target; a window AeroSpace refuses to move is reported and fails
# the run; a bad desktop or flag moves nothing.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	stub_window 100 com.tinyspeck.slackmacgap 1 Slack "General"
	stub_window 200 com.microsoft.VSCode 3 Code "Dotfiles"
	stub_window 300 org.mozilla.firefox 4 Firefox "Docs - Mozilla Firefox"
	cmd=$UNIX_DIR/modules/Window/bin/Move-Windows
}

# Desktop of every stand-in window, in list order.
desktops() {
	cut -d'|' -f4 "$STUB_WINDOWS" | paste -sd' ' -
}

@test "by default every window goes to desktop 1 and desktop 1 is focused" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^aerospace move-node-to-workspace --window-id 200 -- 1$'
	stub_called '^aerospace move-node-to-workspace --window-id 300 -- 1$'
	# Already on the target: not moved.
	! stub_called 'move-node-to-workspace --window-id 100 ' || false
	[ "$(desktops)" = "1 1 1" ]
	[ "$(cat "$BATS_TEST_TMPDIR/focused")" = 1 ]
}

@test "--desktop and --process move only the matching app's windows there" {
	run "${BASH:-bash}" "$cmd" --desktop 5 --process Firefox
	[ "$status" -eq 0 ]
	[ "$(desktops)" = "1 3 5" ]
	[ "$(grep -c move-node-to-workspace "$STUB_LOG")" -eq 1 ]
	[ "$(cat "$BATS_TEST_TMPDIR/focused")" = 5 ]
}

@test "a positional desktop and a title pattern" {
	run "${BASH:-bash}" "$cmd" 2 --window-title '*Docs*'
	[ "$status" -eq 0 ]
	[ "$(desktops)" = "1 3 2" ]
}

@test "with an app and a title pattern a window matching either moves, as on Windows" {
	run "${BASH:-bash}" "$cmd" --desktop 5 --process Slack --window-title '*Docs*'
	[ "$status" -eq 0 ]
	[ "$(desktops)" = "5 3 5" ]
}

@test "--current targets the focused desktop" {
	echo 4 >"$BATS_TEST_TMPDIR/focused"
	run "${BASH:-bash}" "$cmd" --current
	[ "$status" -eq 0 ]
	[ "$(desktops)" = "4 4 4" ]
	! stub_called 'move-node-to-workspace --window-id 300 ' || false
}

@test "--monitor is ignored together with its value" {
	run "${BASH:-bash}" "$cmd" --monitor 2 --desktop 3
	[ "$status" -eq 0 ]
	[ "$(desktops)" = "3 3 3" ]
	! stub_called '^aerospace workspace -- 2$' || false
}

@test "no focused desktop to target fails before moving anything" {
	: >"$BATS_TEST_TMPDIR/focused"
	run "${BASH:-bash}" "$cmd" --current
	[ "$status" -ne 0 ]
	! stub_called 'move-node-to-workspace' || false
	[ "$(desktops)" = "1 3 4" ]
}

@test "a desktop that is not a whole number from 1 to 100, or an unknown flag, fails before anything moves" {
	for argument in 0 101 abc --bogus-flag -WhatIf; do
		run "${BASH:-bash}" "$cmd" "$argument"
		[ "$status" -ne 0 ]
	done
	run "${BASH:-bash}" "$cmd" --desktop 2.5
	[ "$status" -ne 0 ]
	! stub_called '^aerospace' || false
	[ "$(desktops)" = "1 3 4" ]
}

@test "a window AeroSpace refuses to move is reported, the others still move, and the run fails" {
	echo 200 >"$BATS_TEST_TMPDIR/stuck"
	run "${BASH:-bash}" "$cmd" --desktop 5
	[ "$status" -eq 1 ]
	[[ $output == *"1 window(s) could not be moved to desktop 5"* ]]
	[[ $output != *"Moved 2 window(s) to desktop 5!"* ]]
	[ "$(desktops)" = "5 3 5" ]
	[ "$(cat "$BATS_TEST_TMPDIR/focused")" = 5 ]
}
