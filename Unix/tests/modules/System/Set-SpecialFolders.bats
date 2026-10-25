#!/usr/bin/env bats
# Set-SpecialFolders in a throwaway home with a defaults stand-in: Downloads moves to the target
# and becomes a link to it, a name the target has is kept as "NAME (Downloads)", the screenshot
# folder is written, a second run changes nothing, --dry-run changes nothing, no lines do nothing.
# Downloads carries the deny-delete rule macOS puts on it, which the command has to lift.

load ../../helpers

setup() {
	setup_foundation
	use_empty_config
	stub_defaults
	export HOME=$BATS_TEST_TMPDIR/home
	mkdir -p "$HOME/Downloads/folder" "$HOME/Desktop"
	printf 'new\n' >"$HOME/Downloads/report.pdf"
	printf 'dot\n' >"$HOME/Downloads/.hidden"
	printf 'inner\n' >"$HOME/Downloads/folder/a.txt"
	: >"$HOME/Downloads/.localized"
	printf 'mine\n' >"$HOME/Desktop/report.pdf"
	chmod +a "group:everyone deny delete" "$HOME/Downloads"
	printf 'folder Downloads ~/Desktop\nfolder Screenshots ~/Pictures/Shots\n' >"$FOUNDATION_CONFIG_DIR/special-folders.conf"
	cmd=$UNIX_DIR/modules/System/bin/Set-SpecialFolders
}

# A Downloads folder left in place keeps its rule; lift it so the test folder can be removed.
teardown() {
	[ -d "$HOME/Downloads" ] && [ ! -L "$HOME/Downloads" ] && chmod -N "$HOME/Downloads" 2>/dev/null
	return 0
}

@test "Downloads moves to the target, clashes are kept beside, and Downloads becomes a link" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(readlink "$HOME/Downloads")" = "$HOME/Desktop" ]
	[ "$(cat "$HOME/Desktop/report.pdf")" = mine ]
	[ "$(cat "$HOME/Desktop/report (Downloads).pdf")" = new ]
	[ "$(cat "$HOME/Desktop/.hidden")" = dot ]
	[ "$(cat "$HOME/Desktop/folder/a.txt")" = inner ]
	[ ! -e "$HOME/Desktop/.localized" ]
	[ "$(cat "$BATS_TEST_TMPDIR/prefs/location")" = "$HOME/Pictures/Shots" ]
	[ -d "$HOME/Pictures/Shots" ]
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Downloads already goes to"* ]]
	[[ $output == *"Screenshots already go to"* ]]
}

@test "--dry-run and a config without lines change nothing" {
	run "${BASH:-bash}" "$cmd" --dry-run
	[ "$status" -eq 0 ]
	[[ $output == *"would move the contents of $HOME/Downloads"* ]]
	[ -d "$HOME/Downloads" ] && [ ! -L "$HOME/Downloads" ]
	ls -led "$HOME/Downloads" | grep -q 'deny delete'
	[ ! -e "$BATS_TEST_TMPDIR/prefs/location" ]
	: >"$FOUNDATION_CONFIG_DIR/special-folders.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -L "$HOME/Downloads" ]
}

@test "a link elsewhere is replaced; an unknown folder is reported and skipped" {
	chmod -N "$HOME/Downloads"
	rm -rf "$HOME/Downloads"
	mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
	ln -s "$BATS_TEST_TMPDIR/elsewhere" "$HOME/Downloads"
	printf 'folder Documents ~/Desktop\n' >>"$FOUNDATION_CONFIG_DIR/special-folders.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(readlink "$HOME/Downloads")" = "$HOME/Desktop" ]
	[ -d "$BATS_TEST_TMPDIR/elsewhere" ]
	[[ $output == *"Unknown special folder [Documents]"* ]]
}

@test "an already emptied, still protected Downloads folder is replaced by the link" {
	find "$HOME/Downloads" -mindepth 1 -delete
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(readlink "$HOME/Downloads")" = "$HOME/Desktop" ]
}
