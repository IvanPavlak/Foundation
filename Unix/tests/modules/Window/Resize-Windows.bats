#!/usr/bin/env bats
# Resize-Windows against the AeroSpace and osascript stand-ins: each matching window is measured by
# its window id, floated (unless it already floats) and scaled around its center, clamped to the
# 1512 x 949 work area and kept at least 100 points a side, same-titled windows each on their own,
# each desktop shown before its windows are measured and set and the desktop focused before
# restored; 100 percent changes nothing, a percent outside 10-500 touches nothing, --window-handle
# keeps one window, without --percent the window.conf row of the layout machine type applies, and
# a missing Accessibility permission stops the run.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	ax_stub
	stub_window 200 com.microsoft.VSCode 3 Code "Dotfiles"
	stub_window 300 org.mozilla.firefox 4 Firefox "Docs - Mozilla Firefox"
	# The frame the window server reports for each window: 800 x 600 at 100,133.
	printf '%s\n' '200 100 133 800 600' '300 100 133 800 600' >"$STUB_FRAMES"
	cmd=$UNIX_DIR/modules/Window/bin/Resize-Windows
}

# Line number of the first platform call matching the regex.
call_line() {
	grep -nE -- "$1" "$STUB_LOG" | head -1 | cut -d: -f1
}

@test "100 percent touches no window" {
	run "${BASH:-bash}" "$cmd" --percent 100
	[ "$status" -eq 0 ]
	! stub_called '^aerospace' || false
	! stub_called '^osascript' || false
}

@test "50 percent halves each window around its center, measured before it is floated" {
	run "${BASH:-bash}" "$cmd" --percent 50
	[ "$status" -eq 0 ]
	stub_called '^osascript -l JavaScript - set 200 99999999 Dotfiles 300 283 400 300$'
	stub_called '^osascript -l JavaScript - set 300 99999999 Docs - Mozilla Firefox 300 283 400 300$'
	stub_called '^aerospace layout --window-id 200 floating$'
	[ "$(call_line '- frames 200$')" -lt "$(call_line 'layout --window-id 200 floating')" ]
}

@test "enlarging is clamped to the work area" {
	echo "200 1000 500 800 600" >"$STUB_FRAMES"
	run "${BASH:-bash}" "$cmd" --percent 200 --process Code
	[ "$status" -eq 0 ]
	stub_called '^osascript -l JavaScript - set 200 99999999 Dotfiles 0 33 1512 949$'
}

@test "a positional percent and --process pick the windows" {
	run "${BASH:-bash}" "$cmd" 50 --process Firefox
	[ "$status" -eq 0 ]
	stub_called '^osascript -l JavaScript - set 300 99999999 Docs - Mozilla Firefox 300 283 400 300$'
	! stub_called ' 99999999 Dotfiles' || false
	! stub_called 'layout --window-id 200 ' || false
}

@test "--window-title selects by title" {
	run "${BASH:-bash}" "$cmd" --percent 50 --window-title '*Docs*'
	[ "$status" -eq 0 ]
	stub_called '- set 300 99999999 Docs - Mozilla Firefox '
	! stub_called ' 99999999 Dotfiles' || false
}

@test "--current keeps the focused desktop's windows only" {
	echo 3 >"$BATS_TEST_TMPDIR/focused"
	run "${BASH:-bash}" "$cmd" --percent 50 --current
	[ "$status" -eq 0 ]
	stub_called '- set 200 99999999 Dotfiles '
	! stub_called ' 99999999 Docs - Mozilla Firefox' || false
}

@test "a window that already floats is not floated again" {
	: >"$STUB_WINDOWS"
	echo "200|com.microsoft.VSCode|99999999|3|Code|Dotfiles|floating" >>"$STUB_WINDOWS"
	run "${BASH:-bash}" "$cmd" --percent 50
	[ "$status" -eq 0 ]
	! stub_called 'layout --window-id 200 floating' || false
	stub_called '- set 200 99999999 Dotfiles 300 283 400 300$'
}

@test "a window whose frame cannot be read is skipped untouched, and the run fails" {
	echo "300 100 133 800 600" >"$STUB_FRAMES"
	run "${BASH:-bash}" "$cmd" --percent 50
	[ "$status" -eq 1 ]
	[[ $output == *"1 could not be resized"* ]]
	! stub_called '- set 200 99999999 Dotfiles ' || false
	! stub_called 'layout --window-id 200 ' || false
	stub_called '- set 300 99999999 Docs - Mozilla Firefox 300 283 400 300$'
}

@test "a missing Accessibility permission stops at the first window" {
	touch "$BATS_TEST_TMPDIR/ax-deny"
	run "${BASH:-bash}" "$cmd" --percent 50
	[ "$status" -eq 1 ]
	[ "$(grep -c -- '- set ' "$STUB_LOG")" -eq 1 ]
	! stub_called 'layout --window-id 300 ' || false
}

@test "same-titled windows of one app are each read and scaled by their own window id" {
	: >"$STUB_WINDOWS"
	stub_window 501 com.google.Chrome 1 "Google Chrome" "New Tab - Google Chrome"
	stub_window 502 com.google.Chrome 1 "Google Chrome" "New Tab - Google Chrome"
	printf '%s\n' '501 100 133 800 600' '502 700 233 400 300' >"$STUB_FRAMES"
	run "${BASH:-bash}" "$cmd" --percent 50
	[ "$status" -eq 0 ]
	stub_called '^osascript -l JavaScript - set 501 99999999 New Tab - Google Chrome 300 283 400 300$'
	stub_called '^osascript -l JavaScript - set 502 99999999 New Tab - Google Chrome 800 308 200 150$'
	[ "$(grep -c -- '- set ' "$STUB_LOG")" -eq 2 ]
}

@test "a percent that is not a whole number fails before any window is touched" {
	run "${BASH:-bash}" "$cmd" --percent half
	[ "$status" -ne 0 ]
	! stub_called '^aerospace' || false
	! stub_called '^osascript' || false
}

@test "without --percent: SmallDisplay on the small display, then the machine type, then Default, else 70" {
	copy_fixture_config
	# No small-display machine type: the layout machine type is the machine type itself.
	grep -v '^small-display ' "$FIXTURE_CONFIG/machines.conf" >"$FOUNDATION_CONFIG_DIR/machines.conf"
	printf 'resize-windows Default 50\nresize-windows Laptop 25\n' >>"$FOUNDATION_CONFIG_DIR/window.conf"
	FOUNDATION_MACHINE_TYPE=Work run "${BASH:-bash}" "$cmd" --process Code
	[ "$status" -eq 0 ]
	[[ $output == *"to 50%"* ]]
	FOUNDATION_MACHINE_TYPE=Laptop run "${BASH:-bash}" "$cmd" --process Code
	[[ $output == *"to 25%"* ]]
	printf 'resize-windows SmallDisplay 80\n' >>"$FOUNDATION_CONFIG_DIR/window.conf"
	FOUNDATION_MACHINE_TYPE=Laptop run "${BASH:-bash}" "$cmd" --process Code
	[[ $output == *"to 80%"* ]]
	printf 'small-display-width 1000\n' >>"$FOUNDATION_CONFIG_DIR/machines.conf"
	FOUNDATION_MACHINE_TYPE=Laptop run "${BASH:-bash}" "$cmd" --process Code
	[[ $output == *"to 25%"* ]]
	printf 'resize-windows Laptop 900\n' >>"$FOUNDATION_CONFIG_DIR/window.conf"
	FOUNDATION_MACHINE_TYPE=Laptop run "${BASH:-bash}" "$cmd" --process Code
	[[ $output == *"to 70%"* ]]
}

@test "without --percent the row of the layout machine type applies: layout-override, then small-display" {
	copy_fixture_config
	printf 'resize-windows Default 50\nresize-windows Work 25\nresize-windows Laptop 40\n' >>"$FOUNDATION_CONFIG_DIR/window.conf"
	# The fixture's small-display Laptop on the 1512-point panel.
	FOUNDATION_MACHINE_TYPE=Work run "${BASH:-bash}" "$cmd" --process Code
	[ "$status" -eq 0 ]
	[[ $output == *"to 40%"* ]]
	printf 'layout-override Laptop Work\n' >>"$FOUNDATION_CONFIG_DIR/machines.conf"
	FOUNDATION_MACHINE_TYPE=Laptop run "${BASH:-bash}" "$cmd" --process Code
	[ "$status" -eq 0 ]
	[[ $output == *"to 25%"* ]]
}

@test "a window.conf row that is not a number gives 70, a fraction is rounded" {
	copy_fixture_config
	printf 'resize-windows Default abc\n' >>"$FOUNDATION_CONFIG_DIR/window.conf"
	run "${BASH:-bash}" "$cmd" --process Code
	[ "$status" -eq 0 ]
	[[ $output == *"to 70%"* ]]
	printf 'resize-windows Default 33.5\n' >>"$FOUNDATION_CONFIG_DIR/window.conf"
	run "${BASH:-bash}" "$cmd" --process Code
	[ "$status" -eq 0 ]
	[[ $output == *"to 34%"* ]]
}

@test "a percent outside 10-500 fails before any window is touched" {
	for percent in 0 9 501; do
		run "${BASH:-bash}" "$cmd" --percent "$percent"
		[ "$status" -ne 0 ]
	done
	! stub_called '^aerospace' || false
	! stub_called '- set ' || false
}

@test "a resized window keeps at least 100 points a side" {
	run "${BASH:-bash}" "$cmd" --percent 10 --process Code
	[ "$status" -eq 0 ]
	# 10 % of 800 x 600 is 80 x 60, raised to 100 x 100 around the same center.
	stub_called '^osascript -l JavaScript - set 200 99999999 Dotfiles 450 383 100 100$'
}

@test "--window-handle resizes only that window" {
	run "${BASH:-bash}" "$cmd" --percent 50 --window-handle 300
	[ "$status" -eq 0 ]
	stub_called '^osascript -l JavaScript - set 300 99999999 Docs - Mozilla Firefox 300 283 400 300$'
	[ "$(grep -c -- '- set ' "$STUB_LOG")" -eq 1 ]
}

@test "--window-handle of no listed window, or not an id, fails before any window is touched" {
	run "${BASH:-bash}" "$cmd" --percent 50 --window-handle 999
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" --percent 50 --window-handle abc
	[ "$status" -ne 0 ]
	! stub_called '- set ' || false
	! stub_called 'layout --window-id' || false
}

@test "each desktop is shown before its windows are measured and resized, and the desktop focused before comes back" {
	# AeroSpace parks a hidden desktop's windows in a corner and refuses changes to them.
	touch "$BATS_TEST_TMPDIR/layout-needs-focus"
	echo 7 >"$BATS_TEST_TMPDIR/focused"
	run "${BASH:-bash}" "$cmd" --percent 50
	[ "$status" -eq 0 ]
	# The frames are the shown ones, not the parked 1511,941.
	stub_called '^osascript -l JavaScript - set 200 99999999 Dotfiles 300 283 400 300$'
	stub_called '^osascript -l JavaScript - set 300 99999999 Docs - Mozilla Firefox 300 283 400 300$'
	[ "$(call_line '^aerospace workspace -- 3$')" -lt "$(call_line '- frames 200$')" ]
	[ "$(call_line '^aerospace workspace -- 4$')" -lt "$(call_line '- frames 300$')" ]
	[ "$(call_line '- set 200 ')" -lt "$(call_line '^aerospace workspace -- 4$')" ]
	[ "$(cat "$BATS_TEST_TMPDIR/focused")" = 7 ]
}

@test "a desktop AeroSpace does not show counts its windows as not resized and fails the run" {
	mv "$STUB_BIN/aerospace" "$STUB_BIN/aerospace-stub"
	printf '#!/bin/sh\nif [ "$1" = workspace ]; then echo "aerospace $*" >>"$STUB_LOG"; exit 1; fi\nexec "%s/aerospace-stub" "$@"\n' "$STUB_BIN" >"$STUB_BIN/aerospace"
	chmod +x "$STUB_BIN/aerospace"
	run "${BASH:-bash}" "$cmd" --percent 50
	[ "$status" -eq 1 ]
	[[ $output == *"2 could not be resized"* ]]
	! stub_called '- set ' || false
}
