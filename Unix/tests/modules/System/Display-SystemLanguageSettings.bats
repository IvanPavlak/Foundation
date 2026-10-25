#!/usr/bin/env bats
# Display-SystemLanguageSettings against a stub `defaults` and a stand-in input-source helper:
# prints the languages, the region and the keyboard layouts, names what language.conf configures,
# and lists the defaults only when some are set.

load ../../helpers

setup() {
	setup_foundation
	use_empty_config
	# The global preferences the stub reports (AppleMeasurementUnits only when MEASUREMENT is set).
	export APPLE_LANGUAGES='(
    "en-US",
    "hr-HR"
)' APPLE_LOCALE='en_US@rg=hrzzzz'
	stub_tool defaults 'case "$*" in
		*AppleLanguages*) printf "%s\n" "$APPLE_LANGUAGES" ;;
		*AppleLocale*) printf "%s\n" "$APPLE_LOCALE" ;;
		*AppleMeasurementUnits*) [ -n "${MEASUREMENT:-}" ] || exit 1; printf "%s\n" "$MEASUREMENT" ;;
	esac'
	helper=$BATS_TEST_TMPDIR/inputsource
	printf '#!/bin/sh\nprintf "com.apple.keylayout.Croatian-PC\\t1\\tCroatian PC\\ncom.apple.keylayout.US\\t0\\tU.S.\\n"\n' >"$helper"
	chmod +x "$helper"
	export FOUNDATION_INPUTSOURCE_HELPER=$helper
	cmd=$UNIX_DIR/modules/System/bin/Display-SystemLanguageSettings
}

@test "prints the languages, the region and the layouts, naming the configured ones" {
	cat >"$FOUNDATION_CONFIG_DIR/language.conf" <<-EOF
		display-language English-US en-US
		locale Croatian hr-HR
		keyboard-layout Croatian com.apple.keylayout.Croatian-PC
		keyboard-set Croatian Croatian
		default-locale Croatian
	EOF
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"en-US (English-US)"* ]]
	[[ $output == *"hr-HR"* ]]
	[[ $output != *"hr-HR ("* ]]
	[[ $output == *"en_US@rg=hrzzzz"* ]]
	[[ $output == *"HR (Croatian)"* ]]
	[[ $output == *"follow the region"* ]]
	[[ $output == *"com.apple.keylayout.Croatian-PC  Croatian PC (Croatian) [selected]"* ]]
	[[ $output == *"com.apple.keylayout.US  U.S."* ]]
	[[ $output != *"U.S. ("* ]]
	[[ $output == *"Locale            Croatian"* ]]
	[[ $output == *"Keyboard set      (none)"* ]]
}

@test "a locale without a region override takes its country, and set units show" {
	APPLE_LOCALE=hr_HR MEASUREMENT=Centimeters run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Region       HR"* ]]
	[[ $output == *"Units        Centimeters"* ]]
}

@test "without language.conf entries no name is shown and no defaults are listed" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"en-US"* ]]
	[[ $output != *"en-US ("* ]]
	[[ $output != *Defaults* ]]
}

@test "a helper that fails is reported and the rest still prints" {
	printf '#!/bin/sh\nexit 1\n' >"$helper"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Could not read the keyboard layouts"* ]]
	[[ $output == *"en_US@rg=hrzzzz"* ]]
}
