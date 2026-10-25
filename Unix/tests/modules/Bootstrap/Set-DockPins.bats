#!/usr/bin/env bats
# Set-DockPins against stand-ins for dockutil (its --list output comes from $DOCK_LIST), killall
# and defaults, with fake apps in the test folder and a throwaway backup sink: an unchanged Dock is
# left alone, a different one is backed up, then rebuilt in order with one Dock restart, a failed
# backup changes nothing, clear off only adds, missing apps are skipped, folder options and
# spacers reach dockutil, @TYPE lines apply per machine, --dry-run changes nothing.

load ../../helpers

setup() {
	setup_foundation
	copy_fixture_config
	apps=$BATS_TEST_TMPDIR/Applications
	mkdir -p "$apps/One.app" "$apps/Two Words.app" "$apps/Three.app" "$BATS_TEST_TMPDIR/Folder With Space"
	export DOCK_LIST=$BATS_TEST_TMPDIR/dock-list
	: >"$DOCK_LIST"
	stub_tool dockutil 'case "$1" in --list) cat "$DOCK_LIST" ;; esac'
	stub_tool killall 'exit 0'
	stub_tool defaults 'case "$1" in export) echo dock-plist >"$3" ;; esac'
	export FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/sink
	for tool in dockutil killall defaults; do
		[ "$(command -v "$tool")" = "$BATS_TEST_TMPDIR/tools/$tool" ] || {
			echo "stub guard: $tool resolves to $(command -v "$tool")" >&2
			return 1
		}
	done
	cmd=$UNIX_DIR/modules/Bootstrap/bin/Set-DockPins
}

conf() { printf '%s\n' "$@" >"$FOUNDATION_CONFIG_DIR/dock.conf"; }
# One dockutil --list line for an app: LABEL URL SECTION PLIST BUNDLE, tab separated.
listed() { printf '%s\tfile://%s/\t%s\t/plist\tid\n' x "$1" "${2:-persistentApps}" >>"$DOCK_LIST"; }
changes() { grep -E '^(dockutil --(add|remove)|killall)' "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null || true; }

@test "a Dock that already matches is left alone, URL-encoded paths included" {
	conf "clear on" "pin $apps/One.app" "pin $apps/Two Words.app"
	listed "$apps/One.app"
	listed "${apps// /%20}/Two%20Words.app"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"already matches"* ]]
	[ -z "$(changes)" ]
}

@test "a different Dock is rebuilt in file order with one restart at the end" {
	conf "clear on" "pin $apps/Two Words.app" "pin $apps/One.app"
	listed "$apps/One.app"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(changes)" = "dockutil --remove all --no-restart
dockutil --add $apps/Two Words.app --no-restart
dockutil --add $apps/One.app --no-restart
killall Dock" ]
}

@test "the Dock is backed up before it is emptied, and a failed backup changes nothing" {
	conf "clear on" "pin $apps/One.app"
	listed "$apps/Two Words.app"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(cat "$FOUNDATION_BACKUP_ROOT"/System/DockLayout/*/com.apple.dock.plist)" = dock-plist ]
	[ "$(grep -E '^(defaults export|dockutil --remove)' "$BATS_TEST_TMPDIR/tool.log" | cut -d' ' -f1-2)" = "defaults export
dockutil --remove" ]
	rm -f "$BATS_TEST_TMPDIR/tool.log"
	# A sink that cannot be created: a regular file where its folder goes.
	FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/not-a-folder
	: >"$FOUNDATION_BACKUP_ROOT"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"Could not back up the Dock"* ]]
	[ -z "$(changes)" ]
	rm -f "$BATS_TEST_TMPDIR/tool.log"
	FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/sink
	stub_tool defaults 'exit 1'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[ -z "$(changes)" ]
}

@test "clear off only adds the missing pins and keeps the rest" {
	conf "clear off" "pin $apps/One.app" "pin $apps/Three.app"
	listed "$apps/One.app"
	run "${BASH:-bash}" "$cmd"
	[ "$(changes)" = "dockutil --add $apps/Three.app --no-restart
killall Dock" ]
}

@test "without a clear line only the missing pins are added, as the base file's clear off" {
	conf "pin $apps/One.app" "pin $apps/Three.app"
	listed "$apps/Two Words.app"
	listed "$apps/One.app"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(changes)" = "dockutil --add $apps/Three.app --no-restart
killall Dock" ]
}

@test "an app that is not installed is skipped with a warning" {
	conf "clear on" "pin $apps/One.app" "pin $apps/Missing.app"
	listed "$apps/One.app"
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"Not installed, not pinned"* ]]
	[ -z "$(changes)" ]
}

@test "folders get their section and options, spacers always rebuild" {
	conf "clear on" "pin $apps/One.app" "spacer" "folder $BATS_TEST_TMPDIR/Folder With Space --view fan --display stack"
	listed "$apps/One.app"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	changes | grep -qxF -- 'dockutil --add  --type spacer --section apps --no-restart'
	changes | grep -qxF -- "dockutil --add $BATS_TEST_TMPDIR/Folder With Space --section others --view fan --display stack --no-restart"
}

@test "an @TYPE line applies only on its machine type" {
	conf "clear on" "pin $apps/One.app" "@Work pin $apps/Three.app"
	listed "$apps/One.app"
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"already matches"* ]]
	FOUNDATION_MACHINE_TYPE=Work run "${BASH:-bash}" "$cmd"
	changes | grep -qxF "dockutil --add $apps/Three.app --no-restart"
}

@test "--dry-run and --list change nothing" {
	conf "clear on" "pin $apps/Three.app"
	run "${BASH:-bash}" "$cmd" --dry-run
	[ "$status" -eq 0 ]
	[[ $output == *"dockutil --add $apps/Three.app --no-restart"* ]]
	[[ $output == *"killall Dock"* ]]
	[[ $output == *"would back up com.apple.dock"* ]]
	[ ! -e "$FOUNDATION_BACKUP_ROOT" ]
	run "${BASH:-bash}" "$cmd" --list
	[[ $output == *"In dock.conf (clear on)"* ]]
	[ -z "$(changes)" ]
}

@test "a failed dockutil call fails the run, an unknown argument and a missing dock.conf are errors" {
	conf "clear on" "pin $apps/One.app"
	stub_tool dockutil 'case "$1" in --list) ;; *) exit 1 ;; esac'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	run "${BASH:-bash}" "$cmd" --bogus
	[ "$status" -ne 0 ]
	rm "$FOUNDATION_CONFIG_DIR/dock.conf"
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"Missing Unix/config/dock.conf"* ]]
}
