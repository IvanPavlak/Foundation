#!/usr/bin/env bats
# Set-Locale against a stand-in `defaults`: writes the region into AppleLocale as System Settings
# does (the language kept, @rg= only when the region differs from the language's country), skips a
# region already set, and picks the default on Enter.

load ../../helpers

setup() {
	setup_foundation
	use_empty_config
	stub_defaults
	prefs=$BATS_TEST_TMPDIR/prefs
	defaults write -g AppleLanguages -array en-US
	defaults write -g AppleLocale -string en_US
	: >"$BATS_TEST_TMPDIR/tool.log"
	cat >"$FOUNDATION_CONFIG_DIR/language.conf" <<-EOF
		locale Croatian hr-HR
		locale English-US en-US
		locale NoRegion hr
		default-locale Croatian
	EOF
	cmd=$UNIX_DIR/modules/System/bin/Set-Locale
}

@test "the named locale's region goes into AppleLocale, the language stays" {
	run "${BASH:-bash}" "$cmd" croatian
	[ "$status" -eq 0 ]
	[ "$(cat "$prefs/AppleLocale")" = en_US@rg=hrzzzz ]
	run "${BASH:-bash}" "$cmd" English-US
	[ "$status" -eq 0 ]
	[ "$(cat "$prefs/AppleLocale")" = en_US ]
}

@test "a region already set changes nothing" {
	defaults write -g AppleLocale -string en_US@rg=hrzzzz
	: >"$BATS_TEST_TMPDIR/tool.log"
	run "${BASH:-bash}" "$cmd" Croatian
	[ "$status" -eq 0 ]
	[[ $output == *"already set"* ]]
	! grep -q 'defaults write' "$BATS_TEST_TMPDIR/tool.log" || false
}

@test "without an AppleLocale the first display language gives the language" {
	rm "$prefs/AppleLocale"
	run "${BASH:-bash}" "$cmd" Croatian
	[ "$status" -eq 0 ]
	[ "$(cat "$prefs/AppleLocale")" = en_US@rg=hrzzzz ]
}

@test "Enter in the menu picks the default" {
	printf '\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(cat "$prefs/AppleLocale")" = en_US@rg=hrzzzz ]
}

@test "an unknown name or a code without a region fails, no locales change nothing" {
	run "${BASH:-bash}" "$cmd" Klingon
	[ "$status" -eq 1 ]
	run "${BASH:-bash}" "$cmd" NoRegion
	[ "$status" -eq 1 ]
	: >"$FOUNDATION_CONFIG_DIR/language.conf"
	run "${BASH:-bash}" "$cmd" Croatian
	[ "$status" -eq 0 ]
	! grep -q 'defaults write' "$BATS_TEST_TMPDIR/tool.log" || false
}

@test "the Windows -Locale NAME works like a bare NAME" {
	run "${BASH:-bash}" "$cmd" -Locale Croatian
	[ "$status" -eq 0 ]
	[ "$(cat "$prefs/AppleLocale")" = en_US@rg=hrzzzz ]
}
