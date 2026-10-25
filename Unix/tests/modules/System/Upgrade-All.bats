#!/usr/bin/env bats
# Upgrade-All against brew, mas and sudo stand-ins: Homebrew (pinned list, update, upgrade) and
# AppStore (mas upgrade through sudo, only when mas lists an outdated app) by default, MacOS
# (softwareupdate through sudo) only when named; a manager whose tool is missing is skipped, not
# failed; any failure fails the run without stopping the next manager, and an unknown manager or
# flag fails it before any manager runs.

load ../../helpers

setup() {
	setup_foundation
	stub_tool brew "[ \"\$1\" = update ] && [ -f '$BATS_TEST_TMPDIR/brew-fails' ] && exit 1; [ \"\$1\" = list ] && printf '%s' \"\$BREW_PINNED\"; exit 0"
	stub_tool mas "[ \"\$1\" = outdated ] && printf '%s' \"\$MAS_OUTDATED\"; exit 0"
	stub_tool sudo "[ -f '$BATS_TEST_TMPDIR/sudo-fails' ] && exit 1; exit 0"
	export BREW_PINNED='' MAS_OUTDATED=''
	[ "$(command -v brew)" = "$BATS_TEST_TMPDIR/tools/brew" ]
	[ "$(command -v mas)" = "$BATS_TEST_TMPDIR/tools/mas" ]
	[ "$(command -v sudo)" = "$BATS_TEST_TMPDIR/tools/sudo" ]
	log=$BATS_TEST_TMPDIR/tool.log
	cmd=$UNIX_DIR/modules/System/bin/Upgrade-All
}

@test "Homebrew and AppStore are the default; nothing outdated in the App Store asks no password" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(cat "$log")" = "$(printf 'brew list --pinned\nbrew update\nbrew upgrade\nmas outdated')" ]
}

@test "pinned formulae are listed before the Homebrew upgrade" {
	BREW_PINNED=$'node\npython@3.12' run "${BASH:-bash}" "$cmd" Homebrew
	[ "$status" -eq 0 ]
	[[ $output == *"Skipping version-pinned packages"* ]]
	[[ $output == *"  - node"* ]]
	[[ $output == *"  - python@3.12"* ]]
}

@test "outdated App Store apps are listed and upgraded through sudo" {
	MAS_OUTDATED='497799835 Xcode (16.0 -> 16.1)' run "${BASH:-bash}" "$cmd" AppStore
	[ "$status" -eq 0 ]
	[[ $output == *"Xcode (16.0 -> 16.1)"* ]]
	[ "$(cat "$log")" = "$(printf 'mas outdated\nsudo mas upgrade')" ]
	touch "$BATS_TEST_TMPDIR/sudo-fails"
	MAS_OUTDATED='497799835 Xcode (16.0 -> 16.1)' run "${BASH:-bash}" "$cmd" mas
	[ "$status" -ne 0 ]
}

@test "MacOS runs softwareupdate through sudo, without Homebrew" {
	run "${BASH:-bash}" "$cmd" MacOS
	[ "$status" -eq 0 ]
	[ "$(cat "$log")" = "sudo softwareupdate --install --all" ]
}

@test "several managers run in order; the Windows -PackageManager spelling and brew alias work" {
	run "${BASH:-bash}" "$cmd" -PackageManager brew softwareupdate
	[ "$status" -eq 0 ]
	[ "$(cat "$log")" = "$(printf 'brew list --pinned\nbrew update\nbrew upgrade\nsudo softwareupdate --install --all')" ]
}

@test "a failed brew update skips the upgrade and fails the run" {
	touch "$BATS_TEST_TMPDIR/brew-fails"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	grep -qx 'brew update' "$log"
	! grep -qx 'brew upgrade' "$log" || false
}

@test "a failed system update fails the run" {
	touch "$BATS_TEST_TMPDIR/sudo-fails"
	run "${BASH:-bash}" "$cmd" MacOS
	[ "$status" -ne 0 ]
}

@test "an unknown manager or flag fails before any manager runs" {
	run "${BASH:-bash}" "$cmd" Nope
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" Homebrew Nope
	[ "$status" -ne 0 ]
	[[ $output == *"Unknown package manager => Nope"* ]]
	run "${BASH:-bash}" "$cmd" Homebrew --bogus-flag
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" Homebrew -WhatIf
	[ "$status" -ne 0 ]
	[ ! -e "$log" ]
}

@test "a comma list names several managers, as -PackageManager Homebrew,MacOS does" {
	run "${BASH:-bash}" "$cmd" Homebrew,MacOS
	[ "$status" -eq 0 ]
	[ "$(cat "$log")" = "$(printf 'brew list --pinned\nbrew update\nbrew upgrade\nsudo softwareupdate --install --all')" ]
}

@test "a missing brew is skipped with a warning, not a failure, and the App Store still runs" {
	hide_tool brew
	MAS_OUTDATED='497799835 Xcode (16.0 -> 16.1)' run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"[Homebrew] is not installed"* ]]
	[ "$(cat "$log")" = "$(printf 'mas outdated\nsudo mas upgrade')" ]
}

@test "a missing mas is skipped with a warning, not a failure, after Homebrew ran" {
	hide_tool mas
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"mas is not installed"* ]]
	[ "$(cat "$log")" = "$(printf 'brew list --pinned\nbrew update\nbrew upgrade')" ]
}

@test "a failing mas outdated is reported and fails the run, the next manager still runs, nothing is upgraded" {
	stub_tool mas "[ \"\$1\" = outdated ] && exit 1; exit 0"
	run "${BASH:-bash}" "$cmd" AppStore MacOS
	[ "$status" -ne 0 ]
	[[ $output == *"could not list the outdated App Store apps"* ]]
	[[ $output == *"1 failure(s)"* ]]
	[ "$(cat "$log")" = "$(printf 'mas outdated\nsudo softwareupdate --install --all')" ]
}
