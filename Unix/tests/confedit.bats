#!/usr/bin/env bats
# The config writers of the Configuration module: a section is appended once to the .local.conf
# overlay (created when missing), an existing one is refused without touching either file, and
# every write to an existing overlay is backed up first - when the backup fails, nothing is written.

load helpers

setup() {
	setup_foundation
	foundation_load backup confedit
	export FOUNDATION_CONFIG_DIR="$BATS_TEST_TMPDIR/config"
	export FOUNDATION_BACKUP_ROOT="$BATS_TEST_TMPDIR/sink"
	mkdir -p "$FOUNDATION_CONFIG_DIR"
	printf '# header\n\n[Existing]\nOpen-Obsidian' >"$FOUNDATION_CONFIG_DIR/workspaces.conf"
}

@test "conf_add_section creates the overlay, leaves the base file alone and needs no backup" {
	before=$(cat "$FOUNDATION_CONFIG_DIR/workspaces.conf")
	run conf_add_section "$FOUNDATION_CONFIG_DIR/workspaces.conf" New <<<$'Open-Project New\nFocus-VirtualDesktop 1'
	[ "$status" -eq 0 ]
	[ "$(cat "$FOUNDATION_CONFIG_DIR/workspaces.conf")" = "$before" ]
	[ "$(conf_section "$FOUNDATION_CONFIG_DIR/workspaces.local.conf" new | paste -sd'|' -)" = "Open-Project New|Focus-VirtualDesktop 1" ]
	[ "$(conf_section "$FOUNDATION_CONFIG_DIR/workspaces.conf" new | paste -sd'|' -)" = "Open-Project New|Focus-VirtualDesktop 1" ]
	[ "$(conf_section "$FOUNDATION_CONFIG_DIR/workspaces.conf" Existing)" = "Open-Obsidian" ]
	head -1 "$FOUNDATION_CONFIG_DIR/workspaces.local.conf" | grep -q '^# Overlay of workspaces.conf'
	[ ! -d "$FOUNDATION_BACKUP_ROOT" ]
}

@test "conf_add_section appends to an existing overlay after a blank line and backs it up" {
	printf '[Mine]\nOpen-Code' >"$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	run conf_add_section "$FOUNDATION_CONFIG_DIR/workspaces.conf" New <<<"Open-Project New"
	[ "$status" -eq 0 ]
	[ "$(conf_section "$FOUNDATION_CONFIG_DIR/workspaces.conf" Mine)" = "Open-Code" ]
	[ "$(conf_section "$FOUNDATION_CONFIG_DIR/workspaces.conf" New)" = "Open-Project New" ]
	grep -qx '' "$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	[ -f "$(find "$FOUNDATION_BACKUP_ROOT/Config/workspaces.local" -name workspaces.local.conf | head -1)" ]
}

@test "conf_add_section refuses an existing section (any case) and leaves both files untouched" {
	before=$(cat "$FOUNDATION_CONFIG_DIR/workspaces.conf")
	run conf_add_section "$FOUNDATION_CONFIG_DIR/workspaces.conf" existing <<<"Open-Code"
	[ "$status" -ne 0 ]
	[ "$(cat "$FOUNDATION_CONFIG_DIR/workspaces.conf")" = "$before" ]
	[ ! -e "$FOUNDATION_CONFIG_DIR/workspaces.local.conf" ]
	printf '[Mine]\nOpen-Code\n' >"$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	run conf_add_section "$FOUNDATION_CONFIG_DIR/workspaces.conf" MINE <<<"Open-Code"
	[ "$status" -ne 0 ]
	[[ $output == *"workspaces.local.conf"* ]]
	[ "$(cat "$FOUNDATION_CONFIG_DIR/workspaces.local.conf")" = $'[Mine]\nOpen-Code' ]
	[ ! -d "$FOUNDATION_BACKUP_ROOT" ]
}

@test "conf_set_value: a top-level line of the overlay, replaced in place or put before the first section" {
	before=$(cat "$FOUNDATION_CONFIG_DIR/workspaces.conf")
	run conf_set_value "$FOUNDATION_CONFIG_DIR/workspaces.conf" benchmark off
	[ "$status" -eq 0 ]
	[ "$(cat "$FOUNDATION_CONFIG_DIR/workspaces.conf")" = "$before" ]
	[ "$(tail -1 "$FOUNDATION_CONFIG_DIR/workspaces.local.conf")" = "benchmark off" ]
	printf '\n[Mine]\nOpen-Obsidian\n' >>"$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	run conf_set_value "$FOUNDATION_CONFIG_DIR/workspaces.conf" Benchmark on
	[ "$status" -eq 0 ]
	[ "$(grep -ci '^benchmark' "$FOUNDATION_CONFIG_DIR/workspaces.local.conf")" -eq 1 ]
	[ "$(conf_value "$FOUNDATION_CONFIG_DIR/workspaces.conf" benchmark)" = on ]
	run conf_set_value "$FOUNDATION_CONFIG_DIR/workspaces.conf" layout-stable-ms 1000
	[ "$(grep -n '^layout-stable-ms' "$FOUNDATION_CONFIG_DIR/workspaces.local.conf" | cut -d: -f1)" -lt "$(grep -n '^\[Mine\]' "$FOUNDATION_CONFIG_DIR/workspaces.local.conf" | cut -d: -f1)" ]
	[ "$(conf_section "$FOUNDATION_CONFIG_DIR/workspaces.conf" Mine)" = "Open-Obsidian" ]
	[ "$(find "$FOUNDATION_BACKUP_ROOT/Config" -name workspaces.local.conf | wc -l | tr -d ' ')" -eq 2 ]
}

@test "a backup that cannot be taken writes nothing: conf_add_section and conf_set_value fail" {
	printf '[Mine]\nOpen-Code\nbenchmark on' >"$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	cp "$FOUNDATION_CONFIG_DIR/workspaces.local.conf" "$BATS_TEST_TMPDIR/before"
	# A regular file where the sink's folder goes: the backup cannot be created.
	: >"$BATS_TEST_TMPDIR/not-a-folder"
	export FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/not-a-folder
	run conf_add_section "$FOUNDATION_CONFIG_DIR/workspaces.conf" New <<<"Open-Project New"
	[ "$status" -ne 0 ]
	cmp -s "$FOUNDATION_CONFIG_DIR/workspaces.local.conf" "$BATS_TEST_TMPDIR/before"
	run conf_set_value "$FOUNDATION_CONFIG_DIR/workspaces.conf" benchmark off
	[ "$status" -ne 0 ]
	cmp -s "$FOUNDATION_CONFIG_DIR/workspaces.local.conf" "$BATS_TEST_TMPDIR/before"
}

@test "Add-Project writes paths with ~ and the default actions" {
	printf '' >"$FOUNDATION_CONFIG_DIR/projects.conf"
	run "${BASH:-bash}" "$UNIX_DIR/modules/Configuration/bin/Add-Project" Demo --path ROOT "$HOME/Development/Demo"
	[ "$status" -eq 0 ]
	[ "$(conf_section "$FOUNDATION_CONFIG_DIR/projects.conf" Demo | paste -sd'|' -)" = "path ROOT ~/Development/Demo|action Open-VSCode Demo|action Open-ProjectTerminals Demo" ]
}

@test "Test-ConfigurationSchema: a broken reference is reported, --strict fails, a fixed one passes" {
	cfg=$FOUNDATION_CONFIG_DIR
	mkdir -p "$cfg/layouts/Work"
	cp "$FIXTURE_CONFIG/apps.conf" "$FIXTURE_CONFIG/zones.conf" "$cfg/"
	printf '[Demo]\npath ROOT ~\naction Open-VSCode Demo\ntab ROOT\n' >"$cfg/projects.conf"
	printf '[Group]\nhttps://example.com\n' >"$cfg/browser-groups.conf"
	printf '[W]\nOpen-Project Demo\nOpen-Browser Group\nOpen-Projekt Demo\n' >"$cfg/workspaces.conf"
	printf '[W]\nlayout 1 Five\n1 Middle Code\n' >"$cfg/layouts/Work/W_Work.conf"
	cmd=$UNIX_DIR/modules/Configuration/bin/Test-ConfigurationSchema
	run "${BASH:-bash}" "$cmd" --strict --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"unknown action [Open-Projekt]"* ]]
	[[ $output == *"zone [Middle] is not in zone set [Five]"* ]]
	printf '[W]\nOpen-Project Demo\nOpen-Browser Group\n' >"$cfg/workspaces.conf"
	printf '[W]\nlayout 1 Five\n1 Left Code\n' >"$cfg/layouts/Work/W_Work.conf"
	run "${BASH:-bash}" "$cmd" --strict --quiet
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}
