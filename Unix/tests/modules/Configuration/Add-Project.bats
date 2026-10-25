#!/usr/bin/env bats
# Add-Project: paths with ~, default actions and tab, explicit tabs and run commands.

load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_LOGGING=off FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/sink
	copy_fixture_config
	cmd=$UNIX_DIR/modules/Configuration/bin/Add-Project
}

@test "explicit paths, tabs and run lines, with ~ for the home folder" {
	run "${BASH:-bash}" "$cmd" Demo --path API "$HOME/src/api" --tab API --run API dnr
	[ "$status" -eq 0 ]
	[ "$(conf_section "$FOUNDATION_CONFIG_DIR/projects.conf" Demo | paste -sd'|' -)" = "path API ~/src/api|action Open-VSCode Demo|action Open-ProjectTerminals Demo|tab API|run API dnr" ]
}

@test "without a path the current folder becomes ROOT with one tab" {
	mkdir -p "$BATS_TEST_TMPDIR/here" && cd "$BATS_TEST_TMPDIR/here"
	run "${BASH:-bash}" "$cmd" Here
	conf_section "$FOUNDATION_CONFIG_DIR/projects.conf" Here | grep -qx "tab ROOT"
	conf_section "$FOUNDATION_CONFIG_DIR/projects.conf" Here | grep -q "^path ROOT .*/here$"
}

@test "a Windows flag with no Unix form, an unknown flag or a second NAME writes nothing" {
	before=$(cat "$FOUNDATION_CONFIG_DIR/projects.conf")
	for args in "MyApp -Runnable" "MyApp -TerminalTabs x" "MyApp -BasePath Projects.MyApp" "MyApp --bogus" "MyApp Other"; do
		run "${BASH:-bash}" "$cmd" $args
		[ "$status" -eq 1 ] || {
			echo "$args => $status"
			return 1
		}
	done
	[[ $output == *"One project at a time"* ]]
	[ "$(cat "$FOUNDATION_CONFIG_DIR/projects.conf")" = "$before" ]
	[ ! -e "$FOUNDATION_CONFIG_DIR/projects.local.conf" ]
	! conf_sections "$FOUNDATION_CONFIG_DIR/projects.conf" | grep -qi -- '--' || false
}

@test "--paths adds a tab per key, each with its --path; an unknown key writes nothing" {
	run "${BASH:-bash}" "$cmd" -Name Demo --path API "$HOME/src/api" -Paths ROOT,API
	[ "$status" -eq 0 ]
	conf_section "$FOUNDATION_CONFIG_DIR/projects.conf" Demo | grep -qx 'tab ROOT'
	conf_section "$FOUNDATION_CONFIG_DIR/projects.conf" Demo | grep -qx 'tab API'
	run "${BASH:-bash}" "$cmd" Other --paths UI
	[ "$status" -eq 1 ]
	! conf_section_name "$FOUNDATION_CONFIG_DIR/projects.conf" Other || false
}
