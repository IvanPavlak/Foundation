#!/usr/bin/env bats
# Reset-Windows against the AeroSpace stand-in: every desktop (or only --desktop / --current) gets
# its floating windows tiled again, its tree flattened and its tiles balanced, shown while it is
# retiled and the desktop focused before restored; windows stay on their desktops unless --gather
# moves them all to one first; a desktop AeroSpace refuses fails the run.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	stub_window 200 com.microsoft.VSCode 3 Code "Dotfiles"
	stub_window 300 org.mozilla.firefox 4 Firefox "Docs - Mozilla Firefox"
	# A window Center-Windows took out of the tiling: the stand-in reports its 7th field as layout.
	echo "400|com.tinyspeck.slackmacgap|99999999|3|Slack|General|floating" >>"$STUB_WINDOWS"
	cmd=$UNIX_DIR/modules/Window/bin/Reset-Windows
}

# Line number of the first platform call matching the regex.
call_line() {
	grep -nE -- "$1" "$STUB_LOG" | head -1 | cut -d: -f1
}

@test "every desktop is flattened, retiled and balanced; only floating windows are tiled again" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	for desktop in 3 4; do
		stub_called "^aerospace flatten-workspace-tree --workspace $desktop\$"
		stub_called "^aerospace balance-sizes --workspace $desktop\$"
	done
	stub_called '^aerospace layout --window-id 400 tiling$'
	! stub_called 'layout --window-id 200 tiling' || false
	! stub_called 'layout --window-id 300 tiling' || false
	# The first window of each desktop sets the row layout.
	stub_called '^aerospace layout --window-id 200 h_tiles$'
	stub_called '^aerospace layout --window-id 300 h_tiles$'
	! stub_called 'move-node-to-workspace' || false
}

@test "--desktop resets only that desktop" {
	run "${BASH:-bash}" "$cmd" --desktop 4
	[ "$status" -eq 0 ]
	stub_called '^aerospace flatten-workspace-tree --workspace 4$'
	! stub_called 'flatten-workspace-tree --workspace 3' || false
	! stub_called 'layout --window-id 400 tiling' || false
}

@test "a positional desktop works like --desktop" {
	run "${BASH:-bash}" "$cmd" 3
	[ "$status" -eq 0 ]
	stub_called '^aerospace flatten-workspace-tree --workspace 3$'
	! stub_called 'flatten-workspace-tree --workspace 4' || false
}

@test "--current resets the focused desktop" {
	echo 3 >"$BATS_TEST_TMPDIR/focused"
	run "${BASH:-bash}" "$cmd" --current
	[ "$status" -eq 0 ]
	stub_called '^aerospace balance-sizes --workspace 3$'
	stub_called '^aerospace layout --window-id 400 tiling$'
	! stub_called 'balance-sizes --workspace 4' || false
}

@test "--gather moves every window to that desktop first and resets only it" {
	run "${BASH:-bash}" "$cmd" --gather 2
	[ "$status" -eq 0 ]
	[ "$(cut -d'|' -f4 "$STUB_WINDOWS" | paste -sd' ' -)" = "2 2 2" ]
	stub_called '^aerospace flatten-workspace-tree --workspace 2$'
	stub_called '^aerospace balance-sizes --workspace 2$'
	! stub_called 'flatten-workspace-tree --workspace 3' || false
	! stub_called 'flatten-workspace-tree --workspace 4' || false
}

@test "--monitor and its value are ignored, --center only warns: every desktop is reset" {
	run "${BASH:-bash}" "$cmd" --monitor 4 --center
	[ "$status" -eq 0 ]
	stub_called '^aerospace flatten-workspace-tree --workspace 3$'
	stub_called '^aerospace flatten-workspace-tree --workspace 4$'
}

@test "without windows nothing is flattened" {
	: >"$STUB_WINDOWS"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	! stub_called 'flatten-workspace-tree' || false
	! stub_called 'balance-sizes' || false
}

@test "each desktop is shown before AeroSpace retiles it, and the desktop focused before comes back" {
	touch "$BATS_TEST_TMPDIR/layout-needs-focus"
	echo 7 >"$BATS_TEST_TMPDIR/focused"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(call_line '^aerospace workspace -- 3$')" -lt "$(call_line '^aerospace layout --window-id 400 tiling$')" ]
	[ "$(call_line '^aerospace workspace -- 3$')" -lt "$(call_line '^aerospace layout --window-id 200 h_tiles$')" ]
	[ "$(call_line '^aerospace workspace -- 4$')" -lt "$(call_line '^aerospace layout --window-id 300 h_tiles$')" ]
	[ "$(cat "$BATS_TEST_TMPDIR/focused")" = 7 ]
	[[ $output == *"Reset 3 window(s) on 2 desktop(s)"* ]]
}

@test "a desktop AeroSpace refuses to retile is reported and fails the run" {
	touch "$BATS_TEST_TMPDIR/layout-needs-focus"
	# Desktop switches are refused, so every layout change lands on a hidden desktop.
	mv "$STUB_BIN/aerospace" "$STUB_BIN/aerospace-stub"
	printf '#!/bin/sh\nif [ "$1" = workspace ]; then echo "aerospace $*" >>"$STUB_LOG"; exit 1; fi\nexec "%s/aerospace-stub" "$@"\n' "$STUB_BIN" >"$STUB_BIN/aerospace"
	chmod +x "$STUB_BIN/aerospace"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[[ $output == *"desktop(s) 3 4 could not be retiled"* ]]
}

@test "a desktop that is not a whole number from 1 to 100, or an unknown flag, fails before anything changes" {
	for arguments in 0 abc "--gather 101" --bogus-flag; do
		run "${BASH:-bash}" "$cmd" $arguments
		[ "$status" -ne 0 ]
	done
	! stub_called '^aerospace' || false
}

@test "a named desktop without a window is reported and fails; no desktop filter still succeeds" {
	run "${BASH:-bash}" "$cmd" --desktop 7
	[ "$status" -eq 1 ]
	[[ $output == *"Desktop 7 has no window - nothing was reset"* ]]
	[[ $output != *"Reset 0 window(s)"* ]]
	! stub_called 'flatten-workspace-tree' || false
}

@test "--gather stops before anything is retiled when a window cannot be moved" {
	echo 200 >"$BATS_TEST_TMPDIR/stuck"
	run "${BASH:-bash}" "$cmd" --gather 2
	[ "$status" -ne 0 ]
	[[ $output == *"nothing was reset"* ]]
	! stub_called 'flatten-workspace-tree' || false
	! stub_called 'balance-sizes' || false
}
