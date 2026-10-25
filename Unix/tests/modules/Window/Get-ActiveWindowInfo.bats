#!/usr/bin/env bats
# Get-ActiveWindowInfo against the AeroSpace and osascript stand-ins: every window (or those whose
# title matches) with its app, PID, desktop, frame (read by window id, so same-titled windows each
# show their own) and layout line; a frame the window server does not list is reported as such;
# --continuous prints a focused window once until focus moves.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	stub_window 200 com.microsoft.VSCode 1 Code "Dotfiles"
	stub_window 300 org.mozilla.firefox 3 Firefox "YouTube - Mozilla Firefox"
	printf '%s\n' '200 100 33 800 600' '300 100 33 800 600' >"$STUB_FRAMES"
	cmd=$UNIX_DIR/modules/Window/bin/Get-ActiveWindowInfo
}

@test "every window with its app, PID, desktop, frame and layout line" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Code (com.microsoft.VSCode), PID 99999999"* ]]
	[[ $output == *"Window    300 on desktop 3"* ]]
	[[ $output == *"Frame     x 100  y 33  width 800  height 600"* ]]
	[[ $output == *"Layout    1 Zone Code Dotfiles"* ]]
	[[ $output == *"Layout    3 Zone Firefox YouTube - Mozilla Firefox"* ]]
}

@test "a title pattern keeps the matching windows only; no match is a warning" {
	run "${BASH:-bash}" "$cmd" '*YouTube*'
	[ "$status" -eq 0 ]
	[[ $output == *"Layout    3 Zone Firefox"* ]]
	[[ $output != *"Zone Code"* ]]
	run "${BASH:-bash}" "$cmd" '*Nothing*'
	[ "$status" -eq 0 ]
	[[ $output == *"No window matches [*Nothing*]"* ]]
}

@test "same-titled windows each show their own frame; an unlisted frame is reported, the rest prints" {
	: >"$STUB_WINDOWS"
	stub_window 501 com.google.Chrome 1 "Google Chrome" "New Tab - Google Chrome"
	stub_window 502 com.google.Chrome 2 "Google Chrome" "New Tab - Google Chrome"
	stub_window 503 com.google.Chrome 2 "Google Chrome" "Docs - Google Chrome"
	printf '%s\n' '501 0 33 756 949' '502 756 33 756 949' >"$STUB_FRAMES"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Frame     x 0  y 33  width 756  height 949"* ]]
	[[ $output == *"Frame     x 756  y 33  width 756  height 949"* ]]
	[[ $output == *"Frame     (could not be read)"* ]]
	[[ $output == *"Layout    2 Zone Chrome Docs - Google Chrome"* ]]
}

@test "--continuous prints the focused window once while focus stays" {
	echo 300 >"$BATS_TEST_TMPDIR/focused-window"
	FOUNDATION_ACTIVE_WINDOW_POLLS=3 run "${BASH:-bash}" "$cmd" --continuous
	[ "$status" -eq 0 ]
	[ "$(grep -c 'Layout    3 Zone Firefox' <<<"$output")" -eq 1 ]
	[[ $output != *"Zone Code"* ]]
	FOUNDATION_ACTIVE_WINDOW_POLLS=2 run "${BASH:-bash}" "$cmd" --continuous '*Nothing*'
	[ "$status" -eq 0 ]
	[[ $output != *Layout* ]]
}
