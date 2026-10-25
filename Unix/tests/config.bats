#!/usr/bin/env bats
# Config readers: the section/value/overlay rules against throwaway files, the zone, layout,
# app, browser-group and project readers against the fixture config.

load helpers

setup() {
	setup_foundation
	use_empty_config
	cat >"$FOUNDATION_CONFIG_DIR/demo.conf" <<'EOF'
top-key value one
# comment
[Alpha]
line 1
  line 2

[beta]
x
EOF
	cat >"$FOUNDATION_CONFIG_DIR/demo.local.conf" <<'EOF'
[Beta]
overridden
EOF
}

@test "sections: base plus overlay, no duplicates, case-insensitive" {
	run conf_sections "$FOUNDATION_CONFIG_DIR/demo.conf"
	[ "$output" = $'Alpha\nbeta' ]
}

@test "section: trimmed lines, comments dropped" {
	run conf_section "$FOUNDATION_CONFIG_DIR/demo.conf" alpha
	[ "$output" = $'line 1\nline 2' ]
}

@test "section: local overlay replaces the base section" {
	run conf_section "$FOUNDATION_CONFIG_DIR/demo.conf" BETA
	[ "$output" = "overridden" ]
}

@test "section: missing section fails" {
	run conf_section "$FOUNDATION_CONFIG_DIR/demo.conf" gamma
	[ "$status" -ne 0 ]
}

@test "value: key lookup before the first section" {
	[ "$(conf_value "$FOUNDATION_CONFIG_DIR/demo.conf" top-key)" = "value one" ]
}

@test "machine type: host line wins over MACHINE_TYPE" {
	printf 'host %s Work\ndefault Laptop\n' "$(foundation_hostname)" >"$FOUNDATION_CONFIG_DIR/machines.conf"
	MACHINE_TYPE=Laptop
	[ "$(foundation_machine_type)" = "Work" ]
}

@test "machine type: default when nothing matches" {
	printf 'host no-such-host Work\ndefault PC\n' >"$FOUNDATION_CONFIG_DIR/machines.conf"
	unset MACHINE_TYPE
	[ "$(foundation_machine_type)" = "PC" ]
}

@test "machine type: Test without a default line or MACHINE_TYPE" {
	printf 'host no-such-host Work\n' >"$FOUNDATION_CONFIG_DIR/machines.conf"
	unset MACHINE_TYPE FOUNDATION_MACHINE_TYPE
	[ "$(foundation_machine_type)" = "Test" ]
}

@test "machine type: FOUNDATION_MACHINE_TYPE wins even without machines.conf" {
	export FOUNDATION_MACHINE_TYPE=PC MACHINE_TYPE=Work
	[ "$(foundation_machine_type)" = "PC" ]
}

@test "machine types: type lines of base and overlay in order, duplicates in any case dropped" {
	printf 'type Work\ntype Laptop\nhost h Work\n' >"$FOUNDATION_CONFIG_DIR/machines.conf"
	printf 'type laptop\ntype Studio\n' >"$FOUNDATION_CONFIG_DIR/machines.local.conf"
	run foundation_machine_types
	[ "$output" = $'Work\nLaptop\nStudio' ]
	rm "$FOUNDATION_CONFIG_DIR/machines.conf" "$FOUNDATION_CONFIG_DIR/machines.local.conf"
	run foundation_machine_types
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "conf_effective: overlay sections replace base ones in place, new ones follow, lines filtered" {
	printf '%s\n' 'pre base' '@Work pre work' '[A]' 'a1' '[B]' 'b1' '@Laptop b2' '[C]' 'c1' >"$FOUNDATION_CONFIG_DIR/eff.conf"
	printf '%s\n' 'pre local' '-pre base' '[b]' 'b-local' '[D]' 'd1' >"$FOUNDATION_CONFIG_DIR/eff.local.conf"
	CONF_MACHINE_TYPE=Work run conf_effective "$FOUNDATION_CONFIG_DIR/eff.conf"
	[ "$output" = $'pre work\npre local\n[A]\na1\n[B]\nb-local\n[C]\nc1\n[D]\nd1' ]
	rm "$FOUNDATION_CONFIG_DIR/eff.local.conf"
	CONF_MACHINE_TYPE=Laptop run conf_effective "$FOUNDATION_CONFIG_DIR/eff.conf"
	[ "$output" = $'pre base\n[A]\na1\n[B]\nb1\nb2\n[C]\nc1' ]
}

@test "browser groups: an overlay group, a nested group in the overlay and @TYPE URLs resolve" {
	printf '%s\n' '[Code]' 'https://base.example/code' '[Docs]' 'https://base.example/docs' >"$FOUNDATION_CONFIG_DIR/browser-groups.conf"
	printf '%s\n' '[Docs]' 'https://local.example/docs' '@Work Intranet https://work.example' '[Code.Mine]' 'https://local.example/mine' >"$FOUNDATION_CONFIG_DIR/browser-groups.local.conf"
	CONF_MACHINE_TYPE=Work run browser_group_urls Docs
	[ "$output" = $'Docs\nhttps://local.example/docs\nhttps://work.example' ]
	CONF_MACHINE_TYPE=Laptop run browser_group_urls Code
	[ "$output" = $'Code\nhttps://base.example/code\nhttps://local.example/mine' ]
	CONF_MACHINE_TYPE=Laptop run browser_group_urls Intranet
	[ "$status" -ne 0 ]
}

# The readers below run against the fixture config (Unix/tests/fixtures/config), whose values
# they assert; setup() points at an empty folder for the demo.conf tests above.

@test "zones: column and share, aliases" {
	export FOUNDATION_CONFIG_DIR=$FIXTURE_CONFIG
	[ "$(zone_column Five Left)" = "0 67.25 0" ]
	[ "$(zone_column Five Right)" = "1 32.75 0" ]
	[ "$(zone_column Three Far-Right)" = "3 25 0" ]
	[ "$(zone_column Four Top-Left)" = "0 50 0" ]
	[ "$(zone_column Nine Bottom-Middle)" = "1 33.33 1" ]
	! zone_column Five Middle || false
}

@test "layouts: desktops first, then one entry per window with zone, app and title" {
	export FOUNDATION_CONFIG_DIR=$FIXTURE_CONFIG
	run layout_entries "$FIXTURE_CONFIG/layouts/Work/Sample_Work.conf" sample
	[ "${lines[0]}" = $'L\t1\tPrimary\tFive' ]
	[ "${lines[1]}" = $'L\t2\tPrimary\tOne' ]
	[ "${lines[2]}" = $'W\t1\tPrimary\tLeft\tCode\t' ]
	[ "${lines[4]}" = $'W\t2\tPrimary\tLeft\tBrowser\t*Reference*' ]
	[ "${#lines[@]}" -eq 6 ]
}

@test "layouts: a project variant replaces the windows of the desktops it names, the base stays" {
	export FOUNDATION_CONFIG_DIR=$FIXTURE_CONFIG
	file=$FIXTURE_CONFIG/layouts/Work/Sample_Work.conf
	run layout_entries "$file" Sample sampleapi
	[ "$(printf '%s\n' "${lines[@]}" | grep '^L' | paste -sd'|' -)" = $'L\t1\tPrimary\tFive|L\t2\tPrimary\tFive' ]
	[ "$(printf '%s\n' "${lines[@]}" | grep $'^W\t2' | paste -sd'|' -)" = $'W\t2\tPrimary\tLeft\tCode\t*SampleApi*|W\t2\tPrimary\tRight\tBrowser\t*Reference*' ]
	[ "$(printf '%s\n' "${lines[@]}" | grep -c $'^W\t1')" -eq 2 ]
	# Another project leaves the base layout alone.
	[ "$(layout_entries "$file" Sample Sample)" = "$(layout_entries "$file" Sample)" ]
	[ "$(layout_variants "$file" Sample)" = $'SampleApi\t2.Primary' ]
	[ -z "$(layout_variant_problems "$file" Sample)" ]
}

@test "layouts: several projects apply in order (the later wins), an unknown project's variant is skipped" {
	copy_fixture_config
	file=$FOUNDATION_CONFIG_DIR/layouts/Work/Multi_Work.conf
	printf '[Multi]\nlayout 1 One\n1 Left Code\nproject Sample\n1 Left Code first\nproject SampleApi\n1 Left Code second\nproject Ghost\nlayout 1 Zero\n1 Fullscreen Code ghost\n' >"$file"
	[ "$(layout_entries "$file" Multi Sample SampleApi | grep '^W' | cut -f6)" = second ]
	[ "$(layout_entries "$file" Multi SampleApi Sample | grep '^W' | cut -f6)" = first ]
	[ "$(layout_entries "$file" Multi Ghost)" = "$(layout_entries "$file" Multi)" ]
	[[ "$(layout_variant_problems "$file" Multi)" == *"names unknown project [Ghost]"* ]]
}

@test "layouts: a bare project line is reported as naming no project" {
	copy_fixture_config
	file=$FOUNDATION_CONFIG_DIR/layouts/Work/Bare_Work.conf
	printf '[Bare]\nlayout 1 One\n1 Left Code\nproject\n1 Right Code other\n' >"$file"
	[ "$(layout_variant_problems "$file" Bare)" = "a project line names no project" ]
}

@test "layouts: layout_entry_problems names an unknown zone set or zone, a desktop without a layout line and an unknown app" {
	copy_fixture_config
	file=$FOUNDATION_CONFIG_DIR/layouts/Work/Broken_Work.conf
	printf '[Broken]\nlayout 1 NoSuchSet\nlayout 2 Five\n1 Left Code\n2 Middle Code\n2 Left Nothing\n2 Right com.microsoft.VSCode\n3 Left Code\n' >"$file"
	run layout_entry_problems < <(layout_entries "$file" Broken)
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "desktop 1 uses unknown zone set [NoSuchSet]" ]
	[ "${lines[1]}" = "zone [Middle] is not in zone set [Five] (desktop 2)" ]
	[ "${lines[2]}" = "unknown app [Nothing] (not an apps.conf token or role)" ]
	# A bundle id is no token: a layout entry never matches one.
	[ "${lines[3]}" = "unknown app [com.microsoft.VSCode] (not an apps.conf token or role)" ]
	[ "${lines[4]}" = "desktop 3 has entries but no layout line" ]
	[ "${#lines[@]}" -eq 5 ]
	# The fixture's layouts have none; a role (Browser) is a known app.
	[ -z "$(layout_entries "$FOUNDATION_CONFIG_DIR/layouts/Work/Sample_Work.conf" Sample | layout_entry_problems)" ]
}

@test "layouts: a layout resolves in every set that has it, an unknown one in none" {
	export FOUNDATION_CONFIG_DIR=$FIXTURE_CONFIG
	for set in Work Laptop; do
		[ "$(layout_file Sample "$set")" = "$FIXTURE_CONFIG/layouts/$set/Sample_$set.conf" ]
		! layout_file NoSuchLayout "$set" || false
	done
}

@test "apps: roles and tokens" {
	export FOUNDATION_CONFIG_DIR=$FIXTURE_CONFIG
	app_matches Terminal WezTerm
	app_matches Browser Firefox
	! app_matches Browser Code || false
	[ "$(app_bundle Code)" = "com.microsoft.VSCode" ]
	[ "$(app_binary Chrome)" = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]
}

@test "apps: the last line of a token, browser or role wins, so an overlay overrides the base" {
	copy_fixture_config
	cat >"$FOUNDATION_CONFIG_DIR/apps.local.conf" <<'EOF'
app code       com.example.CodeInsiders
app Chrome     com.google.Chrome       /Applications/Other Chrome.app/Contents/MacOS/Other Chrome
browser Chrome --new-window --guest
browser safari -new-window -private-window
role Browser   Chrome
EOF
	[ "$(app_bundle Code)" = "com.example.CodeInsiders" ]
	[ "$(app_token com.example.CodeInsiders)" = "code" ]
	# The base bundle id no longer resolves: the overlay line replaced the token's entry.
	! app_token com.microsoft.VSCode || false
	[ "$(app_binary Chrome)" = "/Applications/Other Chrome.app/Contents/MacOS/Other Chrome" ]
	[ "$(app_browser_args Chrome)" = "--new-window --guest" ]
	# The overlay's browser line has no launch= field: the binary again.
	[ "$(app_browser_launch_mode Chrome)" = exec ]
	[ "$(app_browser_launch_mode Safari)" = exec ]
	[ "$(app_role_members Browser)" = Chrome ]
	# Each token once, in the place of its first line.
	run apps_list
	[ "$(printf '%s\n' "$output" | cut -f1 | grep -ic '^code$')" -eq 1 ]
	[ "$(printf '%s\n' "$output" | cut -f1 | head -1)" = code ]
	[ "$(printf '%s\n' "$output" | grep -c '^Chrome')" -eq 1 ]
}

@test "browser groups: section, nested, last segment, named URL" {
	export FOUNDATION_CONFIG_DIR=$FIXTURE_CONFIG
	run browser_group_urls docs
	[ "${lines[0]}" = "Docs" ]
	[ "${lines[1]}" = "https://docs.example/reference" ]
	[ "${lines[2]}" = "https://docs.example/guide" ]
	run browser_group_urls Personal
	[ "${lines[0]}" = "Code.Personal" ]
	run browser_group_urls SampleRepository
	[ "${lines[1]}" = "https://git.example/me/sample" ]
	# A parent group opens every nested group's URLs, in file order.
	run browser_group_urls Code
	[ "$output" = $'Code\nhttps://git.example/me/sample\nhttps://git.example/work/project' ]
	run browser_group_urls NoSuchGroup
	[ "$status" -ne 0 ]
}

@test "projects: tabs resolve paths, run commands" {
	export FOUNDATION_CONFIG_DIR=$FIXTURE_CONFIG
	run project_tabs sample
	[ "${lines[0]}" = "Sample.ROOT"$'\t'"$DOTFILES_ROOT"$'\tROOT' ]
	[ "$(project_run_command Sample root)" = "npm run dev" ]
}

@test "state: replace, read, forget" {
	printf 'window\t1\tCode\tb\tt\n' | state_replace Demo
	[ "$(state_workspaces)" = "Demo" ]
	[ "$(state_entries demo | cut -f2)" = "1" ]
	state_forget Demo
	[ -z "$(state_entries Demo)" ]
}

@test "value: FOUNDATION_SETTING_OVERRIDES beats the file (Measure-WorkspaceOpen variants)" {
	file=$FIXTURE_CONFIG/workspaces.conf
	[ "$(conf_value "$file" layout-early-move)" = off ]
	FOUNDATION_SETTING_OVERRIDES=$'layout-stable-ms=750\nlayout-early-move=maybe'
	[ "$(conf_value "$file" layout-early-move)" = maybe ]
	[ "$(conf_value "$file" layout-stable-ms)" = 750 ]
	[ "$(conf_value "$file" benchmark)" = on ]
	unset FOUNDATION_SETTING_OVERRIDES
}
