#!/usr/bin/env bats
# Visualize-Layouts against the fixture layouts: each desktop is drawn as its zone set with the
# windows in their zones, project variants after the base, --all and the menu pick workspaces,
# and --update writes the drawing into the layout file as #| lines after backing it up (into
# --backup-root when given); --layout-path draws one file from anywhere.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	# The layout-set detection reads the display width from the osascript stand-in (1512 points:
	# the small-display rule picks the Laptop set).
	platform_stubs
	export FOUNDATION_MACHINE_TYPE=Work FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/sink
	cmd=$UNIX_DIR/modules/Window/bin/Visualize-Layouts
}

@test "a named workspace is drawn desktop by desktop from this machine's layout set" {
	run "${BASH:-bash}" "$cmd" Sample
	[ "$status" -eq 0 ]
	[[ $output == *"Desktop 1 (Primary) - Five"* ]]
	[[ $output == *"Desktop 2 (Primary) - One"* ]]
	[[ $output == *"Code"* ]]
	[[ $output == *"Terminal"* ]]
	[[ $output == *"Browser *Reference*"* ]]
	# The Laptop Sample has no project variant (the Work one does).
	[[ $output != *"Project variant"* ]]
	stub_called 'NSScreen'
}

@test "--layout takes the name, matched case-insensitively" {
	run "${BASH:-bash}" "$cmd" --layout sample
	[ "$status" -eq 0 ]
	[[ $output == *"Desktop 2 (Primary) - One"* ]]
}

@test "--layout-type draws another set, its project variant after the base" {
	run "${BASH:-bash}" "$cmd" Sample --layout-type Work
	[ "$status" -eq 0 ]
	[[ $output == *"Desktop 2 (Primary) - One"* ]]
	[[ $output == *"Project variant [SampleApi]"* ]]
	[[ $output == *"Desktop 2 (Primary) - Five"* ]]
	[[ $output == *"Code *SampleApi*"* ]]
	! stub_called '^osascript' || false
}

@test "a variant naming an unknown project is reported and not drawn, as the layout skips it" {
	copy_fixture_config
	# A valid base: only the variants are under test (an invalid layout is skipped whole).
	printf '[Multi]\nlayout 1 One\n1 Left Code\nproject SampleApi\nlayout 1 Five\n1 Left Code *SampleApi*\nproject Ghost\nlayout 1 Zero\n1 Fullscreen Code ghost\nproject SampleApi,Ghost\nlayout 1 Zero\n1 Fullscreen Code both\n' >"$FOUNDATION_CONFIG_DIR/layouts/Work/Multi_Work.conf"
	run "${BASH:-bash}" "$cmd" Multi --layout-type Work
	[ "$status" -eq 0 ]
	[[ $output == *"Project variant [SampleApi]"* ]]
	[[ $output == *"names unknown project [Ghost]"* ]]
	[[ $output != *"Project variant [Ghost]"* ]]
	[[ $output != *"Project variant [SampleApi,Ghost]"* ]]
	[[ $output != *"Code ghost"* ]]
	[[ $output != *"Code both"* ]]
}

@test "--all draws every workspace of the set" {
	run "${BASH:-bash}" "$cmd" --all
	[ "$status" -eq 0 ]
	# Default, Empty and Sample.
	[[ $output == *"Browser *Search*"* ]]
	[[ $output == *"Desktop 1 (Primary) - One"* ]]
	[[ $output == *"Desktop 1 (Primary) - Five"* ]]
}

@test "an unknown workspace is reported, nothing is drawn for it and the exit status is 1" {
	run "${BASH:-bash}" "$cmd" NoSuchLayoutAnywhere
	[ "$status" -eq 1 ]
	[[ $output != *"Desktop "* ]]
	[[ $output == *"Layout [NoSuchLayoutAnywhere] not found"* ]]
	# The others still draw.
	run "${BASH:-bash}" "$cmd" NoSuchLayoutAnywhere,Sample
	[ "$status" -eq 1 ]
	[[ $output == *"Desktop 1"* ]]
}

@test "a flag it does not know is an error, never a workspace" {
	run "${BASH:-bash}" "$cmd" --udpate
	[ "$status" -eq 1 ]
	[[ $output == *"Unknown argument => --udpate"* ]]
	[[ $output != *"No layout"* ]]
}

@test "an unknown layout set fails" {
	run "${BASH:-bash}" "$cmd" Sample --layout-type NoSuchSet
	[ "$status" -ne 0 ]
	[[ $output != *"Desktop "* ]]
}

@test "without a name and without a terminal the menu fails" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[[ $output != *"Desktop "* ]]
}

@test "without a name the menu answer picks the workspace" {
	export FOUNDATION_TTY=$BATS_TEST_TMPDIR/tty
	printf 'Sample\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Desktop 2 (Primary) - One"* ]]
}

@test "--display-available-layouts draws every zone set with its zone names" {
	run "${BASH:-bash}" "$cmd" --display-available-layouts
	[ "$status" -eq 0 ]
	for set in Zero One Two Three Four Five Six Seven Eight Nine; do
		grep -qx "  $set" <<<"$output"
	done
	[[ $output == *"[Middle-Left]"* ]]
	[[ $output == *"[Bottom-Right]"* ]]
	[[ $output != *"Desktop "* ]]
}

@test "--update writes the drawing under the section header and backs the file up first" {
	copy_fixture_config
	file=$FOUNDATION_CONFIG_DIR/layouts/Work/Sample_Work.conf
	original=$(cat "$file")
	run "${BASH:-bash}" "$cmd" Sample --layout-type Work --update
	[ "$status" -eq 0 ]
	[ "$(sed -n 1p "$file")" = "[Sample]" ]
	[ "$(sed -n 2p "$file")" = "#| Desktop 1 (Primary) - Five" ]
	grep -qx '#| Project variant \[SampleApi\]' "$file"
	# Every other line, the variant included, is unchanged.
	[ "$(grep -v '^#|' "$file")" = "$original" ]
	backup=$(find "$FOUNDATION_BACKUP_ROOT/Config/WindowLayouts.Work.Sample" -name Sample_Work.conf)
	[ "$(cat "$backup")" = "$original" ]
	# The fixture itself is never written.
	! grep -q '^#|' "$FIXTURE_CONFIG/layouts/Work/Sample_Work.conf" || false
}

@test "a second --update replaces the drawing instead of adding another" {
	copy_fixture_config
	file=$FOUNDATION_CONFIG_DIR/layouts/Work/Sample_Work.conf
	original=$(cat "$file")
	run "${BASH:-bash}" "$cmd" Sample --layout-type Work --update
	[ "$status" -eq 0 ]
	first=$(cat "$file")
	run "${BASH:-bash}" "$cmd" Sample --layout-type Work --update
	[ "$status" -eq 0 ]
	[ "$(cat "$file")" = "$first" ]
	[ "$(grep -v '^#|' "$file")" = "$original" ]
	[ "$(find "$FOUNDATION_BACKUP_ROOT/Config/WindowLayouts.Work.Sample" -name Sample_Work.conf | wc -l | tr -d ' ')" -eq 2 ]
}

@test "--layout-path draws every workspace of that file" {
	mkdir -p "$BATS_TEST_TMPDIR/elsewhere/Custom"
	file=$BATS_TEST_TMPDIR/elsewhere/Custom/Pair.conf
	printf '[One]\nlayout 1 Zero\n1 Fullscreen Code\n\n[Two]\nlayout 1 Zero\n1 Fullscreen Browser *Docs*\n' >"$file"
	run "${BASH:-bash}" "$cmd" --layout-path "$file"
	[ "$status" -eq 0 ]
	[[ $output == *"One (Custom)"* ]]
	[[ $output == *"Two (Custom)"* ]]
	[[ $output == *"Browser *Docs*"* ]]
}

@test "--layout-path to a missing file, or with a workspace name, fails" {
	run "${BASH:-bash}" "$cmd" --layout-path "$BATS_TEST_TMPDIR/no-such.conf"
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" Sample --layout-path "$FIXTURE_CONFIG/layouts/Work/Sample_Work.conf"
	[ "$status" -ne 0 ]
}

@test "--update --layout-path writes into that file, --backup-root puts its backup there" {
	mkdir -p "$BATS_TEST_TMPDIR/elsewhere/Custom"
	file=$BATS_TEST_TMPDIR/elsewhere/Custom/Solo.conf
	printf '[Solo]\nlayout 1 Zero\n1 Fullscreen Code\n' >"$file"
	original=$(cat "$file")
	run "${BASH:-bash}" "$cmd" --layout-path "$file" --update --backup-root "$BATS_TEST_TMPDIR/other-sink"
	[ "$status" -eq 0 ]
	[ "$(sed -n 2p "$file")" = "#| Desktop 1 (Primary) - Zero" ]
	backup=$(find "$BATS_TEST_TMPDIR/other-sink/Config/WindowLayouts.Custom.Solo" -name Solo.conf)
	[ "$(cat "$backup")" = "$original" ]
	[ ! -e "$FOUNDATION_BACKUP_ROOT" ]
}

@test "--all without --layout-type draws every layout set; --all --update writes every set's files" {
	run "${BASH:-bash}" "$cmd" --all
	[ "$status" -eq 0 ]
	[[ $output == *"Sample (Laptop)"* ]]
	[[ $output == *"Sample (Work)"* ]]
	# With --layout-type, that set only.
	run "${BASH:-bash}" "$cmd" --all --layout-type Work
	[ "$status" -eq 0 ]
	[[ $output == *"Sample (Work)"* ]]
	[[ $output != *"(Laptop)"* ]]
	copy_fixture_config
	run "${BASH:-bash}" "$cmd" --all --update
	[ "$status" -eq 0 ]
	for set in Work Laptop; do
		[ "$(sed -n 2p "$FOUNDATION_CONFIG_DIR/layouts/$set/Sample_$set.conf")" = "#| Desktop 1 (Primary) - Five" ]
	done
}

@test "a layout with errors is reported and neither drawn nor written; the others still are" {
	copy_fixture_config
	file=$FOUNDATION_CONFIG_DIR/layouts/Work/Broken_Work.conf
	printf '[Broken]\nlayout 1 Five\n1 Middle Code\n1 Left Nothing\n' >"$file"
	original=$(cat "$file")
	run "${BASH:-bash}" "$cmd" Broken,Sample --layout-type Work
	[ "$status" -eq 1 ]
	[[ $output == *"zone [Middle] is not in zone set [Five]"* ]]
	[[ $output == *"unknown app [Nothing]"* ]]
	[[ $output == *"Skipping [Broken] (Work)"* ]]
	[[ $output != *"Broken (Work)"* ]]
	[[ $output == *"Sample (Work)"* ]]
	run "${BASH:-bash}" "$cmd" Broken --layout-type Work --update
	[ "$status" -eq 1 ]
	[ "$(cat "$file")" = "$original" ]
	[ ! -e "$FOUNDATION_BACKUP_ROOT/Config/WindowLayouts.Work.Broken" ]
	# A variant that applies is checked too.
	printf '[Broken]\nlayout 1 Five\n1 Left Code\nproject SampleApi\nlayout 1 NoSuchSet\n1 Left Code\n' >"$file"
	run "${BASH:-bash}" "$cmd" Broken --layout-type Work
	[ "$status" -eq 1 ]
	[[ $output == *"project variant [SampleApi]: desktop 1 uses unknown zone set [NoSuchSet]"* ]]
}
