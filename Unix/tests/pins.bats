#!/usr/bin/env bats
# lib/pins.sh: the pin lines of package-pins.conf and the formulae of the bundled Brewfiles, the
# two sets Upgrade-All's pin reconciliation compares (the reconciliation itself is covered by
# tests/modules/System/Upgrade-All.bats).

load helpers

setup() {
	setup_foundation
	foundation_load pins
	use_empty_config
}

@test "pins_wanted lists the names of one manager's lines, the manager in any case" {
	printf 'brew node\nBrew jq\nother thing\n' >"$FOUNDATION_CONFIG_DIR/package-pins.conf"
	run pins_wanted brew
	[ "$status" -eq 0 ]
	[ "$output" = "$(printf 'node\njq')" ]
}

@test "pins_wanted applies the overlay and machine types" {
	printf 'brew node\nbrew jq\n' >"$FOUNDATION_CONFIG_DIR/package-pins.conf"
	printf -- '-brew node\n@Test brew fzf\n@Other brew bat\n' >"$FOUNDATION_CONFIG_DIR/package-pins.local.conf"
	CONF_MACHINE_TYPE=Test run pins_wanted brew
	[ "$output" = "$(printf 'jq\nfzf')" ]
}

@test "pins_wanted prints nothing and succeeds without the file" {
	run pins_wanted brew
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "pins__brew_managed reads the brewfile lines of bootstrap.conf, naming a tap formula by its short name" {
	printf 'brew "node"\n  brew "user/tap/tool", args: ["HEAD"]\ncask "wezterm"\nmas "Xcode", id: 497799835\n' >"$BATS_TEST_TMPDIR/Brewfile"
	printf '[Packages]\nbrewfile %s\n' "$BATS_TEST_TMPDIR/Brewfile" >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	run pins__brew_managed
	[ "$output" = "$(printf 'node\ntool')" ]
}

@test "pins__brewfiles falls back to Unix/Brewfile and Unix/Brewfile.local" {
	run pins__brewfiles
	[ "$output" = "$(printf '%s\n%s' "$FOUNDATION_UNIX/Brewfile" "$FOUNDATION_UNIX/Brewfile.local")" ]
}

@test "pins_sync leaves a manager without pins alone" {
	stub_tool brew
	run pins_sync AppStore
	[ "$status" -eq 0 ]
	[ ! -e "$BATS_TEST_TMPDIR/tool.log" ]
}
