#!/usr/bin/env bats
# Update-DirectoryNames: folders ending in _YYYY_MM_DD move to today's date; today's, undated and
# taken names are left alone, and --dry-run renames nothing.

load ../../helpers

setup() {
	setup_foundation
	root=$BATS_TEST_TMPDIR/root
	mkdir -p "$root/Report_2026_01_31" "$root/Some_Notes_2025_12_01" "$root/2024_05_06" "$root/Plain" "$root/Bad_2026_1_31"
	today=$(date +%Y_%m_%d)
	cmd=$UNIX_DIR/modules/System/bin/Update-DirectoryNames
}

@test "dated folders move to today's date, the others stay" {
	run "${BASH:-bash}" "$cmd" "$root"
	[ "$status" -eq 0 ]
	[ -d "$root/Report_$today" ]
	[ -d "$root/Some_Notes_$today" ]
	[ -d "$root/$today" ]
	[ -d "$root/Plain" ]
	[ -d "$root/Bad_2026_1_31" ]
	[ ! -e "$root/Report_2026_01_31" ]
	run "${BASH:-bash}" "$cmd" "$root"
	[ "$status" -eq 0 ]
	[[ $output == *"already up to date"* ]]
}

@test "--dry-run renames nothing, the current folder is the default" {
	cd "$root"
	run "${BASH:-bash}" "$cmd" --dry-run
	[ "$status" -eq 0 ]
	[[ $output == *"Would rename \"Report_2026_01_31\" -> \"Report_$today\""* ]]
	[ -d "$root/Report_2026_01_31" ]
	[ ! -e "$root/Report_$today" ]
}

@test "a taken new name is left alone and fails the run" {
	mkdir -p "$root/Report_$today"
	run "${BASH:-bash}" "$cmd" "$root"
	[ "$status" -eq 1 ]
	[ -d "$root/Report_2026_01_31" ]
	[ -d "$root/Some_Notes_$today" ]
}
