#!/usr/bin/env bats
# Set-SystemDefaults against the fixture system-defaults.conf and stand-ins for defaults, killall
# and osascript: exact writes in file order, @TYPE lines, group selection, overlays, one restart
# at the end, dry-run and --list change nothing, a failed write fails the run.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	export HOME=$BATS_TEST_TMPDIR/home
	mkdir -p "$HOME"
	# Each call on one line, arguments separated by | so a value with spaces stays visible as one.
	stub_tool defaults 'printf "%s|" "$@" >>"$BATS_TEST_TMPDIR/defaults.log"; echo >>"$BATS_TEST_TMPDIR/defaults.log"; exit ${DEFAULTS_FAIL:-0}'
	stub_tool killall 'exit 0'
	for tool in defaults killall; do
		[ "$(command -v "$tool")" = "$BATS_TEST_TMPDIR/tools/$tool" ] || {
			echo "stub guard: $tool resolves to $(command -v "$tool")" >&2
			return 1
		}
	done
	cmd=$UNIX_DIR/modules/Bootstrap/bin/Set-SystemDefaults
}

writes() { grep '^write|' "$BATS_TEST_TMPDIR/defaults.log" 2>/dev/null || true; }
killalls() { grep '^killall ' "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null || true; }

@test "every group in file order, values expanded, one restart of each process at the end" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	expected="write|com.apple.dock|autohide|-bool|true|
write|com.apple.dock|tilesize|-int|40|
write|com.apple.dock|tilesize|-int|32|
write|com.apple.finder|FXPreferredViewStyle|-string|Nlsv|
write|com.apple.menuextra.clock|DateFormat|-string|EEE d MMM HH:mm|
write|com.apple.screencapture|location|-string|$HOME/Pictures/Shots|
write|com.apple.dock|persistent-apps|-array|one|two|"
	[ "$(writes)" = "$expected" ]
	[ -d "$HOME/Pictures/Shots" ]
	[ "$(killalls)" = "killall Dock Finder SystemUIServer" ]
	[[ $output == *"Log out for the trackpad."* ]]
}

@test "currenthost writes per host, delete removes a key" {
	run "${BASH:-bash}" "$cmd" Trackpad
	grep -qxF -- '-currentHost|write|NSGlobalDomain|com.apple.mouse.tapBehavior|-int|1|' "$BATS_TEST_TMPDIR/defaults.log"
	grep -qxF 'delete|com.apple.dock|persistent-others|' "$BATS_TEST_TMPDIR/defaults.log"
}

@test "an @TYPE line applies only on its machine type" {
	FOUNDATION_MACHINE_TYPE=Work run "${BASH:-bash}" "$cmd" Dock
	[ "$status" -eq 0 ]
	! writes | grep -q 'tilesize|-int|32' || false
	writes | grep -q 'tilesize|-int|40'
}

@test "GROUP runs only the named groups, --skip leaves groups out, comma lists and any case work" {
	run "${BASH:-bash}" "$cmd" dock,SCREENSHOTS
	[ "$(writes | cut -d'|' -f2 | sort -u | tr '\n' ' ')" = "com.apple.dock com.apple.screencapture " ]
	[ "$(killalls)" = "killall Dock SystemUIServer" ]
	: >"$BATS_TEST_TMPDIR/defaults.log"
	run "${BASH:-bash}" "$cmd" --skip Dock,Finder --skip Trackpad,Theme
	[ "$(writes | cut -d'|' -f2 | sort -u)" = "com.apple.screencapture" ]
}

@test "an unknown group name is reported" {
	run "${BASH:-bash}" "$cmd" Nonsense
	[ "$status" -eq 0 ]
	[[ $output == *"No group [Nonsense]"* ]]
	[ -z "$(writes)" ]
}

@test "an empty section in the local overlay turns a group off" {
	copy_fixture_config
	printf '[Dock]\n' >"$FOUNDATION_CONFIG_DIR/system-defaults.local.conf"
	run "${BASH:-bash}" "$cmd" Dock
	[ "$status" -eq 0 ]
	[ -z "$(writes)" ]
	[[ $output == *"Dock (nothing for this machine)"* ]]
}

@test "--dry-run and --list print the commands and change nothing" {
	for mode in --dry-run --list; do
		run "${BASH:-bash}" "$cmd" "$mode"
		[ "$status" -eq 0 ]
		[[ $output == *"defaults write com.apple.dock autohide -bool true"* ]]
		[[ $output == *"killall Dock Finder SystemUIServer"* ]]
		[[ $output == *"foundation_run Set-SystemTheme Dark --skip SetWallpaper"* ]]
		[ ! -s "$BATS_TEST_TMPDIR/defaults.log" ]
		[ -z "$(killalls)" ]
		[ ! -d "$HOME/Pictures/Shots" ]
		! stub_called osascript || false
	done
}

@test "a command line runs that Foundation command" {
	run "${BASH:-bash}" "$cmd" Theme
	[ "$status" -eq 0 ]
	stub_called 'osascript .*set dark mode to true'
}

@test "a failed write is reported and fails the run, the other writes still happen" {
	DEFAULTS_FAIL=1 run "${BASH:-bash}" "$cmd" Dock
	[ "$status" -eq 1 ]
	[ "$(writes | wc -l | tr -d ' ')" -eq 3 ]
	[[ $output == *"failure(s)"* ]]
}

@test "a missing system-defaults.conf is an error" {
	use_empty_config
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[[ $output == *"Missing Unix/config/system-defaults.conf"* ]]
}

@test "a key in double quotes keeps its spaces, in the write and in the dry-run line" {
	copy_fixture_config
	printf '[Printing]\ndefaults com.apple.print.PrintingPrefs "Quit When Finished" -bool true\ndelete com.apple.print.PrintingPrefs "Old Key"\n' >"$FOUNDATION_CONFIG_DIR/system-defaults.local.conf"
	run "${BASH:-bash}" "$cmd" Printing
	[ "$status" -eq 0 ]
	[ "$(writes)" = "write|com.apple.print.PrintingPrefs|Quit When Finished|-bool|true|" ]
	grep -qxF 'delete|com.apple.print.PrintingPrefs|Old Key|' "$BATS_TEST_TMPDIR/defaults.log"
	run "${BASH:-bash}" "$cmd" Printing --dry-run
	[[ $output == *'defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true'* ]]
	[[ $output == *'defaults delete com.apple.print.PrintingPrefs "Old Key"'* ]]
}

@test "an unclosed quote skips the line with a warning, the rest of the group still runs" {
	copy_fixture_config
	printf '[Printing]\ndefaults com.apple.print.PrintingPrefs "Quit When Finished -bool true\ndefaults com.apple.print.PrintingPrefs Other -bool true\n' >"$FOUNDATION_CONFIG_DIR/system-defaults.local.conf"
	run "${BASH:-bash}" "$cmd" Printing
	[ "$status" -eq 0 ]
	[[ $output == *"Unclosed quote, skipped"* ]]
	[ "$(writes)" = "write|com.apple.print.PrintingPrefs|Other|-bool|true|" ]
}
