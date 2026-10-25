#!/usr/bin/env bats
# Open-ClaudeDesktop against the platform stand-ins: it is Open-Application for the Claude entry
# of apps.conf - launched by bundle id unless it already has a window, an error without the entry.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	copy_fixture_config
	printf '\napp Claude com.anthropic.claudefordesktop\n' >>"$FOUNDATION_CONFIG_DIR/apps.conf"
	cmd=$UNIX_DIR/modules/Application/bin/Open-ClaudeDesktop
}

@test "launches the Claude app by its bundle id" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^open -b com\.anthropic\.claudefordesktop$'
}

@test "a Claude window already open is left alone" {
	stub_window 50 com.anthropic.claudefordesktop 1 Claude "Claude"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	! stub_called '^open' || false
}

@test "fails without a Claude entry in apps.conf" {
	export FOUNDATION_CONFIG_DIR=$FIXTURE_CONFIG
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	! stub_called '^open' || false
}

@test "--help prints its own header, not Open-Application's, and opens nothing" {
	run "${BASH:-bash}" "$cmd" --help
	[ "$status" -eq 0 ]
	[[ ${lines[0]} == "Open-ClaudeDesktop - "* ]]
	! stub_called '^open' || false
}
