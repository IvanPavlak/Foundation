#!/usr/bin/env bats
# The @TYPE machine filter of lib/config.sh (conf_for_machine, conf_lines, conf_section,
# conf_value) and the read -r field split the new readers use.

load helpers

setup() {
	setup_foundation
	use_empty_config
	file=$FOUNDATION_CONFIG_DIR/demo.conf
	cat >"$file" <<'CONF'
top everywhere
@Laptop top laptop only
@work,PC top work or pc
[Power]
sleep 0
@Laptop displaysleep 5
@Work displaysleep 30
CONF
}

@test "lines without a prefix apply everywhere, prefixed lines only on their type" {
	CONF_MACHINE_TYPE=Laptop run conf_lines "$file"
	[ "$output" = $'top everywhere\ntop laptop only' ]
}

@test "a comma list of types and the comparison are case-insensitive" {
	CONF_MACHINE_TYPE=pc run conf_lines "$file"
	[ "$output" = $'top everywhere\ntop work or pc' ]
}

@test "conf_section filters a section and fails for a missing one" {
	CONF_MACHINE_TYPE=Work run conf_section "$file" power
	[ "$output" = $'sleep 0\ndisplaysleep 30' ]
	run conf_section "$file" Missing
	[ "$status" -ne 0 ]
}

@test "without CONF_MACHINE_TYPE the machine type comes from foundation_machine_type" {
	# No machines.conf in the empty config dir: foundation_machine_type falls back to MACHINE_TYPE.
	export MACHINE_TYPE=Work
	run conf_section "$file" Power
	[ "$output" = $'sleep 0\ndisplaysleep 30' ]
}

@test "the local overlay is filtered too, and an empty overlay section empties the group" {
	printf '[Power]\n@Laptop sleep 15\n' >"$FOUNDATION_CONFIG_DIR/demo.local.conf"
	CONF_MACHINE_TYPE=Laptop run conf_section "$file" Power
	[ "$output" = "sleep 15" ]
	printf '[Power]\n' >"$FOUNDATION_CONFIG_DIR/demo.local.conf"
	CONF_MACHINE_TYPE=Laptop run conf_section "$file" Power
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "a prefix alone on a line yields nothing" {
	printf '@Laptop\nkept\n' >"$file"
	CONF_MACHINE_TYPE=Laptop run conf_lines "$file"
	[ "$output" = kept ]
}

@test "read -r keeps the trailing field with its spaces and expands no glob" {
	line='defaults com.apple.dock persistent-others -string * and a long value'
	read -r kind domain key type rest <<<"$line"
	[ "$kind $domain $key $type" = "defaults com.apple.dock persistent-others -string" ]
	[ "$rest" = '* and a long value' ]
}

@test "conf_value: the last line for this machine type wins, a bare key is empty, a missing key fails" {
	printf '%s\n' 'Version 8.0.11' '@Work version 9.* and more' 'empty' >"$FOUNDATION_CONFIG_DIR/value.conf"
	CONF_MACHINE_TYPE=Laptop run conf_value "$FOUNDATION_CONFIG_DIR/value.conf" version
	[ "$output" = "8.0.11" ]
	CONF_MACHINE_TYPE=Work run conf_value "$FOUNDATION_CONFIG_DIR/value.conf" VERSION
	[ "$output" = "9.* and more" ]
	run conf_value "$FOUNDATION_CONFIG_DIR/value.conf" empty
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	run conf_value "$FOUNDATION_CONFIG_DIR/value.conf" missing
	[ "$status" -ne 0 ]
}

@test "a file without an @ line never resolves the machine type" {
	printf '%s\n' 'plain line' '[S]' 'inside' >"$FOUNDATION_CONFIG_DIR/plain.conf"
	foundation_machine_type() { echo resolved; }
	run conf_lines "$FOUNDATION_CONFIG_DIR/plain.conf"
	[ "$output" = "plain line" ]
	run conf_section "$FOUNDATION_CONFIG_DIR/plain.conf" S
	[ "$output" = inside ]
}

@test "foundation_machine_type reads machines.conf even when it holds an @ line" {
	printf '%s\n' '@Work small-display Work' 'default Test' >"$FOUNDATION_CONFIG_DIR/machines.conf"
	unset MACHINE_TYPE FOUNDATION_MACHINE_TYPE
	foundation_hostname() { printf 'nohost'; }
	run foundation_machine_type
	[ "$output" = Test ]
}

@test "conf_value keeps inner spaces and FOUNDATION_SETTING_OVERRIDES still beats the file" {
	printf '%s\n' 'title A  B' '@Work title work' >"$FOUNDATION_CONFIG_DIR/spaces.conf"
	CONF_MACHINE_TYPE=Laptop run conf_value "$FOUNDATION_CONFIG_DIR/spaces.conf" title
	[ "$output" = "A  B" ]
	FOUNDATION_SETTING_OVERRIDES=$'title=override' CONF_MACHINE_TYPE=Work run conf_value "$FOUNDATION_CONFIG_DIR/spaces.conf" title
	[ "$output" = override ]
}

@test "a -LINE in the overlay takes back a base line, ignoring case and whitespace runs" {
	printf '%s\n' 'item /Applications/A.app hidden' 'item /Applications/B.app' 'keep X' >"$FOUNDATION_CONFIG_DIR/items.conf"
	printf '%s\n' '-ITEM  /Applications/A.app hidden' '-keep Y' 'item /Applications/C.app' >"$FOUNDATION_CONFIG_DIR/items.local.conf"
	run conf_lines "$FOUNDATION_CONFIG_DIR/items.conf"
	[ "$output" = $'item /Applications/B.app\nkeep X\nitem /Applications/C.app' ]
}

@test "a removal is per machine type too, and removes only earlier lines" {
	printf '%s\n' 'pin A' '@Work -pin A' 'pin B' >"$FOUNDATION_CONFIG_DIR/pins.conf"
	printf '%s\n' '-pin B' 'pin B' >"$FOUNDATION_CONFIG_DIR/pins.local.conf"
	CONF_MACHINE_TYPE=Work run conf_lines "$FOUNDATION_CONFIG_DIR/pins.conf"
	[ "$output" = "pin B" ]
	CONF_MACHINE_TYPE=Laptop run conf_lines "$FOUNDATION_CONFIG_DIR/pins.conf"
	[ "$output" = $'pin A\npin B' ]
}

@test "a removed type line leaves the machine type list" {
	printf '%s\n' 'type Work' 'type PC' >"$FOUNDATION_CONFIG_DIR/machines.conf"
	printf '%s\n' '-type PC' >"$FOUNDATION_CONFIG_DIR/machines.local.conf"
	run foundation_machine_types
	[ "$output" = Work ]
}

@test "the dev root: the clone's parent without a line, the line for this machine type, \$DEV in any path whatever DEV holds" {
	printf 'type Work\ntype Laptop\n' >"$FOUNDATION_CONFIG_DIR/machines.conf"
	[ "$(foundation_dev_root)" = "$(dirname "$DOTFILES_ROOT")" ]
	printf 'dev-root ~/Everywhere\n@Work dev-root ~/WorkDev\n' >"$FOUNDATION_CONFIG_DIR/machines.local.conf"
	[ "$(FOUNDATION_MACHINE_TYPE=Laptop foundation_dev_root)" = "$HOME/Everywhere" ]
	[ "$(FOUNDATION_MACHINE_TYPE=Work foundation_dev_root)" = "$HOME/WorkDev" ]
	[ "$(DEV=/elsewhere FOUNDATION_MACHINE_TYPE=Work foundation_expand_path '$DEV/MyRepo ${DEV}/x $DEVICE')" = "$HOME/WorkDev/MyRepo $HOME/WorkDev/x " ]
}

@test "a machine type that is no type line still resolves, with one warning per run naming its source" {
	printf '%s\n' 'type Work' 'type Laptop' 'default Labtop' >"$FOUNDATION_CONFIG_DIR/machines.conf"
	unset MACHINE_TYPE FOUNDATION_MACHINE_TYPE
	foundation_hostname() { printf 'nohost'; }
	export FOUNDATION_RUN_DIR=$BATS_TEST_TMPDIR/run-one
	mkdir -p "$FOUNDATION_RUN_DIR"
	run foundation_machine_type
	[ "$status" -eq 0 ]
	[[ $output == "Labtop"* ]]
	[[ $output == *"[Labtop] (from the default line of machines.conf) is not a type line of machines.conf (Work Laptop)"* ]]
	# The warning goes to stderr only, and the same run does not repeat it.
	[ "$(foundation_machine_type 2>/dev/null)" = Labtop ]
	run foundation_machine_type
	[ "$output" = Labtop ]
	export FOUNDATION_RUN_DIR=$BATS_TEST_TMPDIR/run-two
	mkdir -p "$FOUNDATION_RUN_DIR"
	FOUNDATION_MACHINE_TYPE=work2 run foundation_machine_type
	[[ $output == "work2"* ]]
	[[ $output == *"[work2] (from FOUNDATION_MACHINE_TYPE)"* ]]
}

@test "a machine type that is a type line, in any case, or a config without type lines stays silent" {
	export FOUNDATION_RUN_DIR=$BATS_TEST_TMPDIR/run
	mkdir -p "$FOUNDATION_RUN_DIR"
	unset MACHINE_TYPE FOUNDATION_MACHINE_TYPE
	foundation_hostname() { printf 'nohost'; }
	printf '%s\n' 'type Work' >"$FOUNDATION_CONFIG_DIR/machines.conf"
	FOUNDATION_MACHINE_TYPE=work run foundation_machine_type
	[ "$output" = work ]
	printf '%s\n' 'default Labtop' >"$FOUNDATION_CONFIG_DIR/machines.conf"
	run foundation_machine_type
	[ "$output" = Labtop ]
	[ ! -e "$FOUNDATION_RUN_DIR/machine-type-warned" ]
}

@test "an @TYPE token that is no type line is named at the verbose level and its line is still dropped" {
	printf '%s\n' 'type Work' 'type Laptop' >"$FOUNDATION_CONFIG_DIR/machines.conf"
	printf '%s\n' '@Labtop,work x' '@Work y' 'z' >"$FOUNDATION_CONFIG_DIR/typo.conf"
	FOUNDATION_LOG_LEVEL=verbose CONF_MACHINE_TYPE=Work run conf_lines "$FOUNDATION_CONFIG_DIR/typo.conf"
	[[ $output == *"@Labtop is not a machine type of machines.conf"* ]]
	[[ $output != *"@work is not"* && $output != *"@Work is not"* ]]
	[[ $output == *$'\nx\ny\nz' ]]
	CONF_MACHINE_TYPE=Work run conf_lines "$FOUNDATION_CONFIG_DIR/typo.conf"
	[ "$output" = $'x\ny\nz' ]
}
