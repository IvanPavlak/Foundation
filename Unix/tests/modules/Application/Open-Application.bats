#!/usr/bin/env bats
# Open-Application against the platform stand-ins: an apps.conf entry (by token or bundle id)
# launches by bundle id with its arguments, an app that already has a window is left alone, and
# an unknown name or a failed launch fails.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	cmd=$UNIX_DIR/modules/Application/bin/Open-Application
}

@test "a token launches its bundle, matched case-insensitively" {
	run "${BASH:-bash}" "$cmd" slack
	[ "$status" -eq 0 ]
	stub_called '^open -b com\.tinyspeck\.slackmacgap$'
}

@test "a bundle id resolves to its entry, extra arguments go to the app" {
	run "${BASH:-bash}" "$cmd" com.tinyspeck.slackmacgap --flag value
	[ "$status" -eq 0 ]
	stub_called '^open -b com\.tinyspeck\.slackmacgap --args --flag value$'
}

@test "an app that already has a window is not launched again" {
	stub_window 50 com.tinyspeck.slackmacgap 1 Slack "General"
	run "${BASH:-bash}" "$cmd" Slack
	[ "$status" -eq 0 ]
	! stub_called '^open' || false
}

@test "a window of another app does not count" {
	stub_window 50 md.obsidian 1 Obsidian "Vault"
	run "${BASH:-bash}" "$cmd" Slack
	[ "$status" -eq 0 ]
	stub_called '^open -b com\.tinyspeck\.slackmacgap$'
}

@test "without AeroSpace answering the app is launched without a window check" {
	stub_window 50 com.tinyspeck.slackmacgap 1 Slack "General"
	printf '#!/bin/sh\necho "aerospace $*" >>"$STUB_LOG"\nexit 1\n' >"$STUB_BIN/aerospace"
	run "${BASH:-bash}" "$cmd" Slack
	[ "$status" -eq 0 ]
	stub_called '^open -b com\.tinyspeck\.slackmacgap$'
	! stub_called '^aerospace list-windows' || false
}

@test "an unknown name or no name at all fails without launching" {
	run "${BASH:-bash}" "$cmd" NoSuchAppAnywhere
	[ "$status" -eq 1 ]
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	! stub_called '^open' || false
}

@test "a launch that fails is an error" {
	printf '#!/bin/sh\necho "open $*" >>"$STUB_LOG"\nexit 1\n' >"$STUB_BIN/open"
	run "${BASH:-bash}" "$cmd" Slack
	[ "$status" -eq 1 ]
	stub_called '^open -b com\.tinyspeck\.slackmacgap$'
}

@test "--list prints every apps.conf token, the overlay's included, and launches nothing" {
	copy_fixture_config
	printf 'app Teams com.microsoft.teams2\n' >"$FOUNDATION_CONFIG_DIR/apps.local.conf"
	run "${BASH:-bash}" "$cmd" --list
	[ "$status" -eq 0 ]
	[[ $output == *$'Slack\n'* ]]
	[ "${lines[-1]}" = Teams ]
	! stub_called '^open' || false
}
