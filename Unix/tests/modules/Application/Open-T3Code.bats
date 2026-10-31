#!/usr/bin/env bats
# Open-T3Code against the platform stand-ins: it is Open-Application for the T3Code entry
# of apps.conf - launched by bundle id unless it already has a window, an error without the entry.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	copy_fixture_config
	printf '\napp T3Code com.t3tools.t3code\n' >>"$FOUNDATION_CONFIG_DIR/apps.conf"
	cmd=$UNIX_DIR/modules/Application/bin/Open-T3Code
}

@test "launches the T3 Code app by its bundle id" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^open -b com\.t3tools\.t3code$'
}

@test "a T3 Code window already open is left alone" {
	stub_window 50 com.t3tools.t3code 1 "T3 Code (Beta)" "T3 Code (Beta)"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	! stub_called '^open' || false
}

@test "fails without a T3Code entry in apps.conf" {
	export FOUNDATION_CONFIG_DIR=$FIXTURE_CONFIG
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	! stub_called '^open' || false
}

@test "--help prints its own header, not Open-Application's, and opens nothing" {
	run "${BASH:-bash}" "$cmd" --help
	[ "$status" -eq 0 ]
	[[ ${lines[0]} == "Open-T3Code - "* ]]
	! stub_called '^open' || false
}
