#!/usr/bin/env bats
# Upgrade-All against brew, mas and sudo stand-ins: Homebrew (pins reconciled with
# package-pins.conf, update, upgrade) and AppStore (mas upgrade through sudo, only when mas lists an outdated app) by default, MacOS
# (softwareupdate through sudo) only when named; a manager whose tool is missing is skipped, not
# failed; any failure fails the run without stopping the next manager, and an unknown manager or
# flag fails it before any manager runs.

load ../../helpers

setup() {
	setup_foundation
	# brew: `list --pinned` prints BREW_PINNED, `list --formula` BREW_INSTALLED; update fails with
	# brew-fails, pin and unpin with pin-fails.
	stub_tool brew "case \"\$1\" in
	update) [ -f '$BATS_TEST_TMPDIR/brew-fails' ] && exit 1 ;;
	list) case \"\$2\" in --pinned) printf '%s' \"\$BREW_PINNED\" ;; --formula) printf '%s' \"\$BREW_INSTALLED\" ;; esac ;;
	pin | unpin) [ -f '$BATS_TEST_TMPDIR/pin-fails' ] && exit 1 ;;
esac
exit 0"
	stub_tool mas "[ \"\$1\" = outdated ] && printf '%s' \"\$MAS_OUTDATED\"; exit 0"
	stub_tool sudo "[ -f '$BATS_TEST_TMPDIR/sudo-fails' ] && exit 1; exit 0"
	export BREW_PINNED='' BREW_INSTALLED='' MAS_OUTDATED=''
	# The pin lines and the Brewfiles they are checked against are the test's own, never the clone's.
	copy_fixture_config
	brewfile=$BATS_TEST_TMPDIR/Brewfile
	printf 'brew "node"\nbrew "python@3.12"\nbrew "user/tap/tool"\ncask "wezterm"\n' >"$brewfile"
	printf '[Packages]\nbrewfile %s\n' "$brewfile" >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	pins=$FOUNDATION_CONFIG_DIR/package-pins.conf
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
	printf 'brew node\nbrew python@3.12\n' >"$pins"
	BREW_PINNED=$'node\npython@3.12' run "${BASH:-bash}" "$cmd" Homebrew
	[ "$status" -eq 0 ]
	[[ $output == *"Skipping version-pinned packages"* ]]
	[[ $output == *"  - node"* ]]
	[[ $output == *"  - python@3.12"* ]]
	[ "$(cat "$log")" = "$(printf 'brew list --pinned\nbrew update\nbrew upgrade')" ]
}

@test "an installed formula with a pin line is pinned before the upgrade" {
	printf 'brew node\n' >"$pins"
	BREW_INSTALLED=$'node\njq' run "${BASH:-bash}" "$cmd" Homebrew
	[ "$status" -eq 0 ]
	[ "$(cat "$log")" = "$(printf 'brew list --pinned\nbrew list --formula -1\nbrew pin node\nbrew list --pinned\nbrew update\nbrew upgrade')" ]
}

@test "a pin line for a formula that is not installed pins nothing and the upgrade still runs" {
	printf 'brew node\n' >"$pins"
	BREW_INSTALLED='jq' run "${BASH:-bash}" "$cmd" Homebrew
	[ "$status" -eq 0 ]
	[[ $output == *"[node] is version-pinned but not installed"* ]]
	! grep -q '^brew pin' "$log" || false
	grep -qx 'brew upgrade' "$log"
}

@test "a Brewfile formula pinned without a line is unpinned; a pin on a formula no Brewfile names stays" {
	# tool comes from a tap (user/tap/tool), which brew list names by its short name.
	BREW_PINNED=$'node\ntool\nhandmade' run "${BASH:-bash}" "$cmd" Homebrew
	[ "$status" -eq 0 ]
	grep -qx 'brew unpin node' "$log"
	grep -qx 'brew unpin tool' "$log"
	! grep -qx 'brew unpin handmade' "$log" || false
	grep -qx 'brew upgrade' "$log"
}

@test "an overlay that takes a base pin line back removes the pin" {
	printf 'brew node\n' >"$pins"
	printf -- '-brew node\n' >"$FOUNDATION_CONFIG_DIR/package-pins.local.conf"
	BREW_PINNED='node' run "${BASH:-bash}" "$cmd" Homebrew
	[ "$status" -eq 0 ]
	grep -qx 'brew unpin node' "$log"
}

@test "a pin that fails skips the Homebrew upgrade and fails the run; the next manager still runs" {
	printf 'brew node\n' >"$pins"
	touch "$BATS_TEST_TMPDIR/pin-fails"
	BREW_INSTALLED='node' run "${BASH:-bash}" "$cmd" Homebrew MacOS
	[ "$status" -ne 0 ]
	[[ $output == *"Upgrading all Homebrew Software skipped"* ]]
	! grep -qx 'brew upgrade' "$log" || false
	grep -qx 'sudo softwareupdate --install --all' "$log"
}

@test "a pin state brew cannot report skips the Homebrew upgrade and fails the run" {
	stub_tool brew "[ \"\$1\" = list ] && exit 1; exit 0"
	run "${BASH:-bash}" "$cmd" Homebrew
	[ "$status" -ne 0 ]
	! grep -qx 'brew update' "$log" || false
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
