#!/usr/bin/env bats
# Center-Windows against the AeroSpace and osascript stand-ins: each matching window is floated
# and given the centered WIDTH% x HEIGHT% frame of the 1512 x 949 work area, by its own window id
# (same-titled windows included), each desktop shown before its windows are set and the desktop
# focused before restored; a missing Accessibility permission stops the run, a window that cannot
# be found is only skipped, and a percentage outside 10-100 touches nothing.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	ax_stub
	stub_window 200 com.microsoft.VSCode 3 Code "Dotfiles"
	stub_window 300 org.mozilla.firefox 4 Firefox "Docs - Mozilla Firefox"
	cmd=$UNIX_DIR/modules/Window/bin/Center-Windows
}

@test "every window is floated and centered at 40 x 50 percent by default" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^aerospace layout --window-id 200 floating$'
	stub_called '^aerospace layout --window-id 300 floating$'
	stub_called '^osascript -l JavaScript - set 200 99999999 Dotfiles 454 270 604 474$'
	stub_called '^osascript -l JavaScript - set 300 99999999 Docs - Mozilla Firefox 454 270 604 474$'
}

@test "--process and the percentages pick the window and its frame" {
	run "${BASH:-bash}" "$cmd" --process Firefox --width-percent 50 --height-percent 60
	[ "$status" -eq 0 ]
	stub_called '^osascript -l JavaScript - set 300 99999999 Docs - Mozilla Firefox 378 223 756 569$'
	! stub_called 'layout --window-id 200 ' || false
	! stub_called '- set 200 99999999 Dotfiles ' || false
}

@test "--window-title selects by title" {
	run "${BASH:-bash}" "$cmd" --window-title '*Docs*'
	[ "$status" -eq 0 ]
	stub_called '^aerospace layout --window-id 300 floating$'
	! stub_called 'layout --window-id 200 ' || false
}

@test "--current keeps the focused desktop's windows only" {
	echo 3 >"$BATS_TEST_TMPDIR/focused"
	run "${BASH:-bash}" "$cmd" --current
	[ "$status" -eq 0 ]
	stub_called '^aerospace layout --window-id 200 floating$'
	! stub_called 'layout --window-id 300 ' || false
}

@test "a percentage that is not a whole number fails before any window is touched" {
	run "${BASH:-bash}" "$cmd" --width-percent 40.5
	[ "$status" -ne 0 ]
	! stub_called '^aerospace layout' || false
	! stub_called '- set ' || false
}

@test "a percentage outside 10-100 fails before any window is touched" {
	for arguments in "--width-percent 0" "--width-percent 9" "--height-percent 101"; do
		run "${BASH:-bash}" "$cmd" $arguments
		[ "$status" -ne 0 ]
	done
	! stub_called '^aerospace' || false
	! stub_called '- set ' || false
}

@test "the range bounds 10 and 100 are accepted" {
	run "${BASH:-bash}" "$cmd" --process Firefox --width-percent 100 --height-percent 10
	[ "$status" -eq 0 ]
	stub_called '^osascript -l JavaScript - set 300 99999999 Docs - Mozilla Firefox 0 460 1512 94$'
}

# Line number of the first platform call matching the regex.
call_line() {
	grep -nE -- "$1" "$STUB_LOG" | head -1 | cut -d: -f1
}

@test "each desktop is shown before its windows are floated and centered, and the desktop focused before comes back" {
	# AeroSpace refuses layout and frame changes off the focused desktop.
	touch "$BATS_TEST_TMPDIR/layout-needs-focus"
	echo 7 >"$BATS_TEST_TMPDIR/focused"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Centered 2 window(s)"* ]]
	[ "$(call_line '^aerospace workspace -- 3$')" -lt "$(call_line '^aerospace layout --window-id 200 floating$')" ]
	[ "$(call_line '^aerospace workspace -- 3$')" -lt "$(call_line '- set 200 99999999 Dotfiles ')" ]
	[ "$(call_line '^aerospace workspace -- 4$')" -lt "$(call_line '- set 300 99999999 Docs - Mozilla Firefox ')" ]
	[ "$(call_line '- set 200 99999999 Dotfiles ')" -lt "$(call_line '^aerospace workspace -- 4$')" ]
	[ "$(cat "$BATS_TEST_TMPDIR/focused")" = 7 ]
}

@test "--current switches no desktop" {
	touch "$BATS_TEST_TMPDIR/layout-needs-focus"
	echo 3 >"$BATS_TEST_TMPDIR/focused"
	run "${BASH:-bash}" "$cmd" --current
	[ "$status" -eq 0 ]
	! stub_called '^aerospace workspace ' || false
	stub_called '^osascript -l JavaScript - set 200 99999999 Dotfiles 454 270 604 474$'
}

@test "a desktop AeroSpace does not show counts its windows as not centered and fails the run" {
	mv "$STUB_BIN/aerospace" "$STUB_BIN/aerospace-stub"
	printf '#!/bin/sh\nif [ "$1" = workspace ]; then echo "aerospace $*" >>"$STUB_LOG"; exit 1; fi\nexec "%s/aerospace-stub" "$@"\n' "$STUB_BIN" >"$STUB_BIN/aerospace"
	chmod +x "$STUB_BIN/aerospace"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"2 could not be centered"* ]]
	! stub_called '- set ' || false
}

@test "a missing Accessibility permission still brings the desktop focused before back" {
	touch "$BATS_TEST_TMPDIR/ax-deny"
	echo 7 >"$BATS_TEST_TMPDIR/focused"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[ "$(cat "$BATS_TEST_TMPDIR/focused")" = 7 ]
}

@test "an unknown argument fails" {
	run "${BASH:-bash}" "$cmd" --no-such-flag
	[ "$status" -ne 0 ]
	! stub_called '- set ' || false
}

@test "a missing Accessibility permission stops at the first window" {
	touch "$BATS_TEST_TMPDIR/ax-deny"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[ "$(grep -c -- '- set ' "$STUB_LOG")" -eq 1 ]
	! stub_called 'layout --window-id 300 ' || false
}

@test "a window System Events cannot find is skipped, the others are still centered, and the run fails" {
	echo Dotfiles >"$BATS_TEST_TMPDIR/ax-missing"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"1 could not be centered"* ]]
	[[ $output != *"Centered 1 window(s) at 40% x 50%!"* ]]
	stub_called '^osascript -l JavaScript - set 200 99999999 Dotfiles '
	stub_called '^osascript -l JavaScript - set 300 99999999 Docs - Mozilla Firefox 454 270 604 474$'
}

@test "an unreadable work area fails before any window is touched" {
	printf '#!/bin/sh\necho "osascript $*" >>"$STUB_LOG"\nexit 0\n' >"$STUB_BIN/osascript"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	! stub_called '^aerospace layout' || false
	! stub_called '- set ' || false
}

@test "same-titled windows of one app are each centered by their own window id" {
	: >"$STUB_WINDOWS"
	stub_window 501 com.google.Chrome 1 "Google Chrome" "New Tab - Google Chrome"
	stub_window 502 com.google.Chrome 1 "Google Chrome" "New Tab - Google Chrome"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^osascript -l JavaScript - set 501 99999999 New Tab - Google Chrome 454 270 604 474$'
	stub_called '^osascript -l JavaScript - set 502 99999999 New Tab - Google Chrome 454 270 604 474$'
	[ "$(grep -c -- '- set ' "$STUB_LOG")" -eq 2 ]
}
