#!/usr/bin/env bats
# Focus-VirtualDesktop against the AeroSpace stand-in: the 1-based number (default 1) is the
# workspace focused, --desktop-offset shifts it, a failed switch fails the command, and a bad number,
# offset or flag switches nothing. The focus is parked on a terminal on that desktop, and the
# command prints its title and a success line, or warns about an empty desktop.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	cmd=$UNIX_DIR/modules/Window/bin/Focus-VirtualDesktop
}

# The aerospace subcommand SUBCOMMAND fails; every other call goes to the stand-in.
fail_aerospace() { # SUBCOMMAND
	mv "$STUB_BIN/aerospace" "$STUB_BIN/aerospace-stub"
	printf '#!/bin/sh\nif [ "$1" = "%s" ]; then echo "aerospace $*" >>"$STUB_LOG"; exit 1; fi\nexec "%s/aerospace-stub" "$@"\n' "$1" "$STUB_BIN" >"$STUB_BIN/aerospace"
	chmod +x "$STUB_BIN/aerospace"
}

@test "without a number desktop 1 is focused" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^aerospace workspace -- 1$'
	[ "$(cat "$BATS_TEST_TMPDIR/focused")" = 1 ]
}

@test "a positional number focuses that desktop" {
	run "${BASH:-bash}" "$cmd" 3
	[ "$status" -eq 0 ]
	stub_called '^aerospace workspace -- 3$'
	! stub_called '^aerospace workspace -- 1$' || false
}

@test "--desktop-number names the desktop too" {
	run "${BASH:-bash}" "$cmd" --desktop-number 4
	[ "$status" -eq 0 ]
	stub_called '^aerospace workspace -- 4$'
}

@test "--desktop-offset shifts the number, also in the Windows spelling" {
	run "${BASH:-bash}" "$cmd" 3 --desktop-offset 2
	[ "$status" -eq 0 ]
	stub_called '^aerospace workspace -- 5$'
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" -DesktopOffset 1
	[ "$status" -eq 0 ]
	stub_called '^aerospace workspace -- 2$'
}

@test "a workspace switch AeroSpace refuses fails the command" {
	fail_aerospace workspace
	run "${BASH:-bash}" "$cmd" 2
	[ "$status" -ne 0 ]
	stub_called '^aerospace workspace -- 2$'
	[ ! -e "$BATS_TEST_TMPDIR/focused" ]
}

@test "a number outside 1-100, a bad offset or an unknown flag fails before any switch" {
	for arguments in 0 101 abc "3 --desktop-offset x" --bogus-flag -WhatIf; do
		run "${BASH:-bash}" "$cmd" $arguments
		[ "$status" -ne 0 ]
	done
	! stub_called '^aerospace' || false
}

@test "the focus is parked on the terminal of that desktop, with the title and success line of Windows" {
	stub_window 100 com.microsoft.VSCode 2 Code "Dotfiles"
	stub_window 101 com.github.wez.wezterm 2 WezTerm "zsh"
	stub_window 102 com.github.wez.wezterm 3 WezTerm "other desktop"
	run "${BASH:-bash}" "$cmd" 2
	[ "$status" -eq 0 ]
	[[ $output == *"Focusing Virtual Desktop 2"* ]]
	[[ $output == *"Focused Virtual Desktop 2!"* ]]
	stub_called '^aerospace focus --window-id 101$'
	! stub_called '^aerospace focus --window-id 10[02]$' || false
}

@test "without a terminal on the desktop AeroSpace's choice of window stays focused" {
	stub_window 100 com.microsoft.VSCode 2 Code "Dotfiles"
	stub_window 102 com.github.wez.wezterm 3 WezTerm "other desktop"
	run "${BASH:-bash}" "$cmd" 1 --desktop-offset 1
	[ "$status" -eq 0 ]
	[[ $output == *"Focused Virtual Desktop 2!"* ]]
	! stub_called '^aerospace focus --window-id' || false
}

@test "an empty desktop is switched to with a warning, not a failure" {
	stub_window 102 com.github.wez.wezterm 3 WezTerm "other desktop"
	run "${BASH:-bash}" "$cmd" 4
	[ "$status" -eq 0 ]
	stub_called '^aerospace workspace -- 4$'
	[[ $output == *"Switched to Virtual Desktop 4, but found no window to focus!"* ]]
	[[ $output != *"Focused Virtual Desktop"* ]]
	! stub_called '^aerospace focus --window-id' || false
}
