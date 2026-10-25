#!/usr/bin/env bats
# Add-WindowLayout: a template file per machine type, a missing set folder created (as Windows);
# an existing layout fails.

load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_LOGGING=off FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/sink
	copy_fixture_config
	cmd=$UNIX_DIR/modules/Configuration/bin/Add-WindowLayout
}

@test "the template lands in every named layout set" {
	run "${BASH:-bash}" "$cmd" NewLayout --machine-type Work,Laptop
	[ "$status" -eq 0 ]
	for set in Work Laptop; do
		[ "$(conf_section "$FOUNDATION_CONFIG_DIR/layouts/$set/NewLayout_$set.conf" NewLayout | paste -sd'|' -)" = "layout 1 Zero|1 Fullscreen   Code" ]
	done
	before=$(ls "$FOUNDATION_CONFIG_DIR/layouts/Work" | wc -l)
	run "${BASH:-bash}" "$cmd" newlayout --machine-type Work
	[ "$status" -ne 0 ]
	[ "$(ls "$FOUNDATION_CONFIG_DIR/layouts/Work" | wc -l)" -eq "$before" ]
	[ "$(conf_sections "$FOUNDATION_CONFIG_DIR/layouts/Work/NewLayout_Work.conf")" = NewLayout ]
}

@test "a missing layout set folder is created, as Windows creates Window/Layouts/<MachineType>/" {
	[ ! -e "$FOUNDATION_CONFIG_DIR/layouts/NewSet" ]
	run "${BASH:-bash}" "$cmd" Another --machine-type NewSet
	[ "$status" -eq 0 ]
	[ "$(conf_sections "$FOUNDATION_CONFIG_DIR/layouts/NewSet/Another_NewSet.conf")" = Another ]
	run "${BASH:-bash}" "$cmd" Another --machine-type ../Escape
	[ "$status" -ne 0 ]
	[ ! -e "$FOUNDATION_CONFIG_DIR/Escape" ]
}

@test "every word after --machine-type is a type, the workspace comes first" {
	run "${BASH:-bash}" "$cmd" --machine-type Work Laptop NewLayout
	[ "$status" -ne 0 ]
	[ -z "$(ls "$FOUNDATION_CONFIG_DIR"/layouts/*/NewLayout_* 2>/dev/null)" ]
}

@test "--simple adds the workspace to simple-layouts in the overlay, after a backup" {
	printf '# mine\nbenchmark off\n\n[Mine]\nFocus-VirtualDesktop 1\n' >"$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	run "${BASH:-bash}" "$cmd" NewLayout --machine-type Work -Simple
	[ "$status" -eq 0 ]
	[ "$(conf_value "$FOUNDATION_CONFIG_DIR/workspaces.conf" simple-layouts)" = "Fullscreen Empty NewLayout" ]
	# The line sits before the overlay's first section; the rest of the overlay is kept.
	[ "$(sed -n '1,3p' "$FOUNDATION_CONFIG_DIR/workspaces.local.conf" | paste -sd'|' -)" = "# mine|benchmark off|simple-layouts Fullscreen Empty NewLayout" ]
	conf_section "$FOUNDATION_CONFIG_DIR/workspaces.conf" Mine | grep -qx 'Focus-VirtualDesktop 1'
	[ -n "$(find "$FOUNDATION_BACKUP_ROOT/Config" -name workspaces.local.conf)" ]
	# A second one replaces the overlay's line; one already simple is left alone.
	run "${BASH:-bash}" "$cmd" Other --machine-type Work --simple
	[ "$(grep -c '^simple-layouts' "$FOUNDATION_CONFIG_DIR/workspaces.local.conf")" -eq 1 ]
	[ "$(conf_value "$FOUNDATION_CONFIG_DIR/workspaces.conf" simple-layouts)" = "Fullscreen Empty NewLayout Other" ]
	run "${BASH:-bash}" "$cmd" newlayout --machine-type Work --simple
	[ "$(conf_value "$FOUNDATION_CONFIG_DIR/workspaces.conf" simple-layouts)" = "Fullscreen Empty NewLayout Other" ]
}

@test "without an overlay --simple creates it; an unknown flag writes nothing" {
	rm -f "$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	run "${BASH:-bash}" "$cmd" NewLayout --machine-type Work --simple
	[ "$status" -eq 0 ]
	grep -qx 'simple-layouts Fullscreen Empty NewLayout' "$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	run "${BASH:-bash}" "$cmd" Bogus --machine-type Work --simpel
	[ "$status" -eq 1 ]
	[ -z "$(ls "$FOUNDATION_CONFIG_DIR"/layouts/*/Bogus_* "$FOUNDATION_CONFIG_DIR"/layouts/*/--simpel* 2>/dev/null)" ]
}
