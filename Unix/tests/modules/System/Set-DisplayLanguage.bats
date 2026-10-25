#!/usr/bin/env bats
# Set-DisplayLanguage against a stand-in `defaults`: puts the chosen language first with the other
# configured ones after it, moves the language part of AppleLocale along with the region kept,
# skips a language already first, and picks the default on Enter.

load ../../helpers

setup() {
	setup_foundation
	use_empty_config
	stub_defaults
	prefs=$BATS_TEST_TMPDIR/prefs
	defaults write -g AppleLanguages -array en-US
	defaults write -g AppleLocale -string en_US@rg=hrzzzz
	: >"$BATS_TEST_TMPDIR/tool.log"
	cat >"$FOUNDATION_CONFIG_DIR/language.conf" <<-EOF
		display-language English-US en-US
		display-language Croatian hr-HR
		default-display-language English-US
	EOF
	cmd=$UNIX_DIR/modules/System/bin/Set-DisplayLanguage
}

@test "the named language goes first, the others follow, AppleLocale keeps its region" {
	run "${BASH:-bash}" "$cmd" croatian
	[ "$status" -eq 0 ]
	[ "$(cat "$prefs/AppleLanguages")" = "$(printf 'hr-HR\nen-US')" ]
	[ -f "$prefs/AppleLanguages.array" ]
	[ "$(cat "$prefs/AppleLocale")" = hr_HR ]
	run "${BASH:-bash}" "$cmd" English-US
	[ "$status" -eq 0 ]
	[ "$(cat "$prefs/AppleLanguages")" = "$(printf 'en-US\nhr-HR')" ]
	[ "$(cat "$prefs/AppleLocale")" = en_US@rg=hrzzzz ]
}

@test "a language already first changes nothing" {
	run "${BASH:-bash}" "$cmd" English-US
	[ "$status" -eq 0 ]
	[[ $output == *"already set"* ]]
	! grep -q 'defaults write' "$BATS_TEST_TMPDIR/tool.log" || false
}

@test "Enter in the menu picks the default, a number picks that entry" {
	defaults write -g AppleLanguages -array hr-HR
	printf '\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(head -n 1 "$prefs/AppleLanguages")" = en-US ]
	printf '2\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(head -n 1 "$prefs/AppleLanguages")" = hr-HR ]
}

@test "an unknown name fails, no terminal fails, and no display languages change nothing" {
	run "${BASH:-bash}" "$cmd" Klingon
	[ "$status" -eq 1 ]
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	: >"$FOUNDATION_CONFIG_DIR/language.conf"
	run "${BASH:-bash}" "$cmd" Croatian
	[ "$status" -eq 0 ]
	! grep -q 'defaults write' "$BATS_TEST_TMPDIR/tool.log" || false
}

@test "the Windows -Language NAME works like a bare NAME" {
	run "${BASH:-bash}" "$cmd" -Language Croatian
	[ "$status" -eq 0 ]
	[ "$(cat "$prefs/AppleLanguages")" = "$(printf 'hr-HR\nen-US')" ]
}
