#!/usr/bin/env bats
# Get-WindowHandle against the AeroSpace and osascript stand-ins: every managed window as ID, app
# token, desktop, title, PID and frame (tab separated when piped; a frame the window server does not
# list leaves its columns empty), narrowed by app (token, role or app name) and/or title, a window
# matching EITHER pattern when both are given.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	stub_window 200 com.microsoft.VSCode 3 Code "Dotfiles"
	stub_window 300 org.mozilla.firefox 4 Firefox "Docs - Mozilla Firefox"
	# A mapped bundle whose app name differs from its apps.conf token.
	stub_window 500 com.github.wez.wezterm 2 wezterm-gui "zsh"
	# Frames for two of the three: the window server does not list 500.
	printf '%s\n' '200 0 33 756 949' '300 756 33 756 949' >"$STUB_FRAMES"
	cmd=$UNIX_DIR/modules/Window/bin/Get-WindowHandle
}

@test "without a filter every window is listed with its token, desktop, title, PID and frame" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "${#lines[@]}" -eq 3 ]
	[ "${lines[0]}" = $'200\tCode\t3\tDotfiles\t99999999\t0\t33\t756\t949' ]
	[ "${lines[1]}" = $'300\tFirefox\t4\tDocs - Mozilla Firefox\t99999999\t756\t33\t756\t949' ]
	[ "${lines[2]}" = $'500\tWezTerm\t2\tzsh\t99999999\t\t\t\t' ]
}

@test "a positional app token keeps only that app's windows" {
	run "${BASH:-bash}" "$cmd" Code
	[ "$status" -eq 0 ]
	[ "$output" = $'200\tCode\t3\tDotfiles\t99999999\t0\t33\t756\t949' ]
}

@test "a role matches its member apps" {
	run "${BASH:-bash}" "$cmd" --process-name Browser
	[ "$status" -eq 0 ]
	[ "$output" = $'300\tFirefox\t4\tDocs - Mozilla Firefox\t99999999\t756\t33\t756\t949' ]
}

@test "the app name AeroSpace reports matches when the token does not" {
	run "${BASH:-bash}" "$cmd" --process-name wezterm-gui
	[ "$status" -eq 0 ]
	[ "$output" = $'500\tWezTerm\t2\tzsh\t99999999\t\t\t\t' ]
}

@test "--window-title matches a title as a regex substring" {
	run "${BASH:-bash}" "$cmd" --window-title Docs
	[ "$status" -eq 0 ]
	[ "$output" = $'300\tFirefox\t4\tDocs - Mozilla Firefox\t99999999\t756\t33\t756\t949' ]
}

@test "with an app and a title a window matching either is listed" {
	run "${BASH:-bash}" "$cmd" --process-name Code --window-title '*Docs*'
	[ "$status" -eq 0 ]
	[ "${#lines[@]}" -eq 2 ]
	[ "${lines[0]%%$'\t'*}" = 200 ]
	[ "${lines[1]%%$'\t'*}" = 300 ]
}

@test "the Windows spelling of the flag works" {
	run "${BASH:-bash}" "$cmd" -ProcessName Code
	[ "$status" -eq 0 ]
	[ "$output" = $'200\tCode\t3\tDotfiles\t99999999\t0\t33\t756\t949' ]
}

@test "a pattern nothing matches lists nothing and still succeeds" {
	run "${BASH:-bash}" "$cmd" --process-name NoSuchAppAnywhere
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "the frames are read in one window-server read" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(grep -c -- '- frames ' "$STUB_LOG")" -eq 1 ]
	stub_called '^osascript -l JavaScript - frames 200 300 500$'
}

@test "a window whose title is empty keeps the PID and frame in their columns" {
	: >"$STUB_WINDOWS"
	stub_window 200 com.microsoft.VSCode 3 Code ""
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$output" = $'200\tCode\t3\t\t99999999\t0\t33\t756\t949' ]
}
