#!/usr/bin/env bats
# Rename-Machine against scutil and sudo stand-ins (sudo only logs, it never runs what it is
# given): a configured current name changes nothing unless --override, a NAME or a menu choice is
# set as ComputerName, HostName and LocalHostName (spaces become hyphens), and failures stop the run.

load ../../helpers

setup() {
	setup_foundation
	copy_fixture_config
	printf 'host Work-PC Work\nhost My-Laptop Laptop\n' >>"$FOUNDATION_CONFIG_DIR/machines.conf"
	current_name Old-Name
	stub_tool sudo "[ -f '$BATS_TEST_TMPDIR/sudo-fails' ] && exit 1; exit 0"
	[ "$(command -v scutil)" = "$BATS_TEST_TMPDIR/tools/scutil" ]
	[ "$(command -v sudo)" = "$BATS_TEST_TMPDIR/tools/sudo" ]
	log=$BATS_TEST_TMPDIR/tool.log
	cmd=$UNIX_DIR/modules/System/bin/Rename-Machine
}

# The name scutil --get LocalHostName reports.
current_name() {
	stub_tool scutil "[ \"\$1\" = --get ] && echo '$1'; exit 0"
}

answers() {
	printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/answers"
	export FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers
}

# Answers for a run that reads the terminal more than once: every prompt reopens FOUNDATION_TTY, and
# a reopened /dev/fd pipe goes on where the last read stopped, where a file starts over.
piped_answers() {
	exec 7< <(printf '%s\n' "$@")
	export FOUNDATION_TTY=/dev/fd/7
}

renamed_to() { # COMPUTER-NAME LOCAL-NAME
	[ "$(grep '^sudo' "$log")" = "$(printf 'sudo scutil --set ComputerName %s\nsudo scutil --set HostName %s\nsudo scutil --set LocalHostName %s' "$1" "$2" "$2")" ]
}

@test "a NAME is set as all three names, spaces hyphenated in the host names" {
	run "${BASH:-bash}" "$cmd" "My Mac"
	[ "$status" -eq 0 ]
	renamed_to "My Mac" My-Mac
}

@test "--name works like the positional NAME" {
	run "${BASH:-bash}" "$cmd" --name Work-PC
	[ "$status" -eq 0 ]
	renamed_to Work-PC Work-PC
}

@test "a current name that is configured (case-insensitive) changes nothing" {
	current_name work-pc
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	! grep -q '^sudo' "$log" || false
}

@test "a NAME equal to the current name changes nothing" {
	run "${BASH:-bash}" "$cmd" Old-Name
	[ "$status" -eq 0 ]
	! grep -q '^sudo' "$log" || false
}

@test "--override shows the menu even on a configured name; the choice is set" {
	current_name Work-PC
	answers 2
	run "${BASH:-bash}" "$cmd" --override
	[ "$status" -eq 0 ]
	renamed_to My-Laptop My-Laptop
}

@test "an unconfigured name and no terminal for the menu renames nothing" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	! grep -q '^sudo' "$log" || false
}

@test "without host lines and without a NAME it fails before any menu" {
	export FOUNDATION_CONFIG_DIR=$FIXTURE_CONFIG
	answers 1
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	! grep -q '^sudo' "$log" || false
}

@test "without machines.conf it fails" {
	use_empty_config
	run "${BASH:-bash}" "$cmd" New-Name
	[ "$status" -ne 0 ]
	! grep -q '^sudo' "$log" || false
}

@test "a refused administrator prompt stops after the first name and fails" {
	touch "$BATS_TEST_TMPDIR/sudo-fails"
	run "${BASH:-bash}" "$cmd" New-Name
	[ "$status" -ne 0 ]
	[ "$(grep -c '^sudo' "$log")" -eq 1 ]
	grep -qx 'sudo scutil --set ComputerName New-Name' "$log"
}

@test "Enter new name at the menu sets the name typed next" {
	piped_answers 3 "New Mac"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	renamed_to "New Mac" New-Mac
}

@test "Enter new name followed by an empty name cancels the rename" {
	piped_answers "enter new name" ""
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	! grep -q '^sudo' "$log" || false
}

@test "a configured name typed at the menu is taken by name" {
	answers my-laptop
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	renamed_to My-Laptop My-Laptop
}

@test "a NAME that breaks the naming rules stops before any scutil call" {
	for bad in "My_Mac" "12345" "$(printf 'a%.0s' {1..64})" "Mac!"; do
		run "${BASH:-bash}" "$cmd" "$bad"
		[ "$status" -ne 0 ]
		[[ $output == *"the name was not changed"* ]]
	done
	! grep -q '^sudo' "$log" || false
	run "${BASH:-bash}" "$cmd" "$(printf 'a%.0s' {1..63})"
	[ "$status" -eq 0 ]
	grep -q '^sudo scutil --set LocalHostName' "$log"
}

@test "a typed new name that breaks the rules is asked again" {
	piped_answers 3 "Bad_Name" "2024" "Good Name"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"can only contain letters"* ]]
	[[ $output == *"consist entirely of numbers"* ]]
	renamed_to "Good Name" Good-Name
}

@test "an invalid typed name followed by an empty one cancels without renaming" {
	piped_answers 3 "Bad_Name" ""
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	! grep -q '^sudo' "$log" || false
}
