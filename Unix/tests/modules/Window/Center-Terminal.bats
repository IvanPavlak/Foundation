#!/usr/bin/env bats
# Center-Terminal against the AeroSpace and osascript stand-ins: the window.conf target size of
# the SmallDisplay row on the small display, else the layout machine type (layout-override, then
# small-display, then the machine type), else Default, else the built-in 1376 x 700, becomes
# shares of the 1512 x 949 work area clamped to the row's bounds and to 10-100, and only the
# WezTerm window is floated and centered at them; an unreadable work area hands over 40 x 50.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	ax_stub
	# No hostname lookup: the machine type is given.
	export FOUNDATION_MACHINE_TYPE=Work
	stub_window 200 com.microsoft.VSCode 1 Code "Dotfiles"
	stub_window 500 com.github.wez.wezterm 1 WezTerm "zsh"
	cmd=$UNIX_DIR/modules/Window/bin/Center-Terminal
}

@test "the Default size is clamped to 72 x 74 percent and only WezTerm is centered" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	# 1376 points = 91 % of 1512, clamped to the 72 % maximum; 700 points = 74 % of 949.
	stub_called '^osascript -l JavaScript - set 500 99999999 zsh 212 156 1088 702$'
	stub_called '^aerospace layout --window-id 500 floating$'
	! stub_called 'layout --window-id 200 ' || false
	! stub_called '- set 200 99999999 Dotfiles ' || false
}

# A wide display for the fixture: the 1512-point panel is no longer small, so the small-display
# rule (small-display Laptop) leaves the machine type alone.
wide_display() {
	printf 'small-display-width 1000\n' >>"$FOUNDATION_CONFIG_DIR/machines.conf"
}

@test "the machine type's own row wins over Default" {
	copy_fixture_config
	wide_display
	echo "center-terminal  Work  756 474  10 90  10 90" >>"$FOUNDATION_CONFIG_DIR/window.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^osascript -l JavaScript - set 500 99999999 zsh 378 270 756 474$'
}

@test "another machine type falls back to the Default row" {
	copy_fixture_config
	echo "center-terminal  Work  756 474  10 90  10 90" >>"$FOUNDATION_CONFIG_DIR/window.conf"
	export FOUNDATION_MACHINE_TYPE=Laptop
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^osascript -l JavaScript - set 500 99999999 zsh 212 156 1088 702$'
}

@test "a small target is raised to the minimum percentages" {
	copy_fixture_config
	wide_display
	echo "center-terminal  Work  100 100  30 72  40 75" >>"$FOUNDATION_CONFIG_DIR/window.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^osascript -l JavaScript - set 500 99999999 zsh 529 318 453 379$'
}

@test "without window.conf the built-in size applies" {
	copy_fixture_config
	rm "$FOUNDATION_CONFIG_DIR/window.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^osascript -l JavaScript - set 500 99999999 zsh 212 156 1088 702$'
}

@test "a work area that stays unreadable fails in Center-Windows before any window is touched" {
	printf '#!/bin/sh\necho "osascript $*" >>"$STUB_LOG"\nexit 0\n' >"$STUB_BIN/osascript"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[[ $output == *"40% x 50%"* ]]
	! stub_called '^aerospace' || false
	! stub_called '- set ' || false
}

@test "an unreadable work area hands Center-Windows its own 40 x 50" {
	# The first display read fails, the one Center-Windows makes answers.
	mv "$STUB_BIN/osascript" "$STUB_BIN/osascript-stub"
	printf '#!/bin/sh\ncase "$*" in *NSScreen*) [ -f "%s/read-once" ] || { touch "%s/read-once"; echo "osascript $*" >>"$STUB_LOG"; exit 0; } ;; esac\nexec "%s/osascript-stub" "$@"\n' \
		"$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR" "$STUB_BIN" >"$STUB_BIN/osascript"
	chmod +x "$STUB_BIN/osascript"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^osascript -l JavaScript - set 500 99999999 zsh 454 270 604 474$'
}

@test "the percentages are clamped into Center-Windows' 10-100 whatever the row's bounds" {
	copy_fixture_config
	wide_display
	echo "center-terminal  Work  10 10  1 200  1 200" >>"$FOUNDATION_CONFIG_DIR/window.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	# 10 % of 1512 x 949, centered.
	stub_called '^osascript -l JavaScript - set 500 99999999 zsh 680 460 151 94$'
}

@test "layout-override picks its target type's row, as on Windows" {
	copy_fixture_config
	wide_display
	printf 'layout-override Work Laptop\n' >>"$FOUNDATION_CONFIG_DIR/machines.conf"
	printf 'center-terminal  Work  1000 800  10 90  10 90\ncenter-terminal  Laptop  756 474  10 90  10 90\n' >>"$FOUNDATION_CONFIG_DIR/window.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^osascript -l JavaScript - set 500 99999999 zsh 378 270 756 474$'
}

@test "on a small display without a SmallDisplay row the small-display machine type's row applies" {
	copy_fixture_config
	# machines.conf of the fixture: small-display Laptop, and 1512 points is small.
	printf 'center-terminal  Work  1000 800  10 90  10 90\ncenter-terminal  Laptop  756 474  10 90  10 90\n' >>"$FOUNDATION_CONFIG_DIR/window.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^osascript -l JavaScript - set 500 99999999 zsh 378 270 756 474$'
}

@test "on the small display the SmallDisplay row wins; on a wide one the machine type's" {
	copy_fixture_config
	printf 'center-terminal  Work  756 474  10 90  10 90\ncenter-terminal  SmallDisplay  604 380  10 90  10 90\n' >>"$FOUNDATION_CONFIG_DIR/window.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	# 604 points = 40 % of 1512 (604), 380 = 40 % of 949 (379 after rounding), centered.
	stub_called '^osascript -l JavaScript - set 500 99999999 zsh 454 318 604 379$'
	printf 'small-display-width 1000\n' >>"$FOUNDATION_CONFIG_DIR/machines.conf"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^osascript -l JavaScript - set 500 99999999 zsh 378 270 756 474$'
}
