#!/usr/bin/env bats
# Add-Workspace: appends a workspace with its actions (default: its layout), refuses an existing one.

load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_LOGGING=off FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/sink
	copy_fixture_config
	cmd=$UNIX_DIR/modules/Configuration/bin/Add-Workspace
}

@test "appends the actions, or the default layout action" {
	run "${BASH:-bash}" "$cmd" NewSpace --action "Open-Project Demo" --action "Focus-VirtualDesktop 2"
	[ "$status" -eq 0 ]
	[ "$(conf_section "$FOUNDATION_CONFIG_DIR/workspaces.conf" NewSpace | paste -sd'|' -)" = "Open-Project Demo|Focus-VirtualDesktop 2" ]
	run "${BASH:-bash}" "$cmd" Plain
	[ "$(conf_section "$FOUNDATION_CONFIG_DIR/workspaces.conf" Plain)" = "Set-WorkspaceWindowLayout Plain" ]
}

@test "an existing workspace is refused and the file stays the same" {
	before=$(cat "$FOUNDATION_CONFIG_DIR/workspaces.conf")
	run "${BASH:-bash}" "$cmd" sample
	[ "$status" -ne 0 ]
	[ "$(cat "$FOUNDATION_CONFIG_DIR/workspaces.conf")" = "$before" ]
}

@test "--template writes an instance with its set lines, actions become add lines" {
	run "${BASH:-bash}" "$cmd" NewSpace --template project --set Repository=Docs --action "Focus-VirtualDesktop 2"
	[ "$status" -eq 0 ]
	[ "$(conf_section "$FOUNDATION_CONFIG_DIR/workspaces.conf" NewSpace | paste -sd'|' -)" = "template Project|set Repository Docs|add Focus-VirtualDesktop 2" ]
}

@test "an unknown template is refused and nothing is written" {
	before=$(cat "$FOUNDATION_CONFIG_DIR/workspaces.conf")
	run "${BASH:-bash}" "$cmd" NewSpace --template NoSuchTemplate
	[ "$status" -ne 0 ]
	[ "$(cat "$FOUNDATION_CONFIG_DIR/workspaces.conf")" = "$before" ]
	[ ! -e "$FOUNDATION_CONFIG_DIR/workspaces.local.conf" ]
}

@test "an unknown flag or a second NAME writes nothing" {
	before=$(cat "$FOUNDATION_CONFIG_DIR/workspaces.conf")
	run "${BASH:-bash}" "$cmd" NewSpace -Bogus
	[ "$status" -eq 1 ]
	run "${BASH:-bash}" "$cmd" NewSpace Other
	[ "$status" -eq 1 ]
	[ "$(cat "$FOUNDATION_CONFIG_DIR/workspaces.conf")" = "$before" ]
	! conf_section_name "$FOUNDATION_CONFIG_DIR/workspaces.conf" NewSpace || false
}
