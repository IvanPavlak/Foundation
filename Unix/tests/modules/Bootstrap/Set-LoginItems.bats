#!/usr/bin/env bats
# Set-LoginItems against a stand-in for osascript (the current login items come from
# $LOGIN_ITEMS) with fake apps in the test folder: only missing items are added, with their name
# and hidden flag, names compare case-insensitively, missing apps are skipped, a refused System
# Events stops the run, --dry-run and --list add nothing.

load ../../helpers

setup() {
	setup_foundation
	copy_fixture_config
	apps=$BATS_TEST_TMPDIR/Applications
	mkdir -p "$apps/One.app" "$apps/Two Words.app"
	export LOGIN_ITEMS=''
	stub_tool osascript 'case "$*" in *"every login item"*) [ -z "$OSA_REFUSE" ] || { echo "Not authorised (-1743)" >&2; exit 1; }; echo "$LOGIN_ITEMS" ;; esac'
	[ "$(command -v osascript)" = "$BATS_TEST_TMPDIR/tools/osascript" ] || {
		echo "stub guard: osascript resolves to $(command -v osascript)" >&2
		return 1
	}
	cmd=$UNIX_DIR/modules/Bootstrap/bin/Set-LoginItems
}

conf() { printf '%s\n' "$@" >"$FOUNDATION_CONFIG_DIR/login-items.conf"; }
added() { grep 'make login item' "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null || true; }

@test "only missing items are added, with their name and hidden flag" {
	conf "item $apps/One.app hidden" "item $apps/Two Words.app"
	LOGIN_ITEMS='one, Something Else' run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(added | wc -l | tr -d ' ')" -eq 1 ]
	added | grep -qF "end run $apps/Two Words.app Two Words false"
}

@test "hidden is passed through" {
	conf "item $apps/One.app hidden"
	run "${BASH:-bash}" "$cmd"
	added | grep -qF "end run $apps/One.app One true"
}

@test "an app that is not installed is skipped, everything present is a success" {
	conf "item $apps/Missing.app" "item $apps/One.app"
	LOGIN_ITEMS='One' run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Not installed, not added"* ]]
	[[ $output == *"already starts at login"* ]]
	[ -z "$(added)" ]
}

@test "a refused System Events stops the run with the Automation hint" {
	conf "item $apps/One.app"
	OSA_REFUSE=1 run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[[ $output == *"Privacy & Security > Automation"* ]]
	[ -z "$(added)" ]
}

@test "--dry-run and --list add nothing" {
	conf "item $apps/One.app hidden"
	run "${BASH:-bash}" "$cmd" --dry-run
	[[ $output == *"add login item $apps/One.app (hidden: true)"* ]]
	run "${BASH:-bash}" "$cmd" --list
	[[ $output == *"In login-items.conf"* ]]
	[ -z "$(added)" ]
}

@test "a missing login-items.conf and an unknown argument are errors" {
	run "${BASH:-bash}" "$cmd" --bogus
	[ "$status" -ne 0 ]
	rm -f "$FOUNDATION_CONFIG_DIR/login-items.conf"
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"Missing Unix/config/login-items.conf"* ]]
}
