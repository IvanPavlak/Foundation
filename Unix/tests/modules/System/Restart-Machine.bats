#!/usr/bin/env bats
# Restart-Machine against an osascript stand-in: the restart goes to System Events only after a
# yes in the Yes/No menu (answered through FOUNDATION_TTY, never stdin) or with --force; anything
# else, no terminal included, cancels, and a failed request fails the command. A yes counts down
# first (FOUNDATION_RESTART_COUNTDOWN=0 here, so no test waits); --selection answers, by name or
# menu number.

load ../../helpers

setup() {
	setup_foundation
	stub_tool osascript 'exit 0'
	[ "$(command -v osascript)" = "$BATS_TEST_TMPDIR/tools/osascript" ]
	answer=$BATS_TEST_TMPDIR/answer
	export FOUNDATION_RESTART_COUNTDOWN=0
	cmd=$UNIX_DIR/modules/System/bin/Restart-Machine
}

# The menu answer: a line of the terminal stand-in. Usage: answers TEXT
answers() {
	printf '%s\n' "$1" >"$answer"
	export FOUNDATION_TTY=$answer
}

restarted() {
	grep -qF 'osascript -e tell application "System Events" to restart' "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null
}

@test "a yes in the menu restarts through System Events" {
	for reply in y Yes 1; do
		: >"$BATS_TEST_TMPDIR/tool.log"
		answers "$reply"
		run "${BASH:-bash}" "$cmd" </dev/null
		[ "$status" -eq 0 ]
		restarted || {
			echo "[$reply] did not restart"
			return 1
		}
	done
	[[ $output == *"Do you want to restart the machine? (default: No)"* ]]
}

@test "no, or an empty Enter, cancels without restarting" {
	for reply in n No ''; do
		answers "$reply"
		run "${BASH:-bash}" "$cmd" </dev/null
		[ "$status" -eq 0 ]
		[[ $output == *"Restart cancelled"* ]]
		! restarted || false
	done
}

@test "without a terminal it cancels, whatever stdin says" {
	run "${BASH:-bash}" "$cmd" <<<"y"
	[ "$status" -eq 0 ]
	[[ $output == *"No selection possible without a terminal"* ]]
	! restarted || false
}

@test "--force (and the Windows -Force) restarts without asking" {
	run "${BASH:-bash}" "$cmd" --force </dev/null
	[ "$status" -eq 0 ]
	restarted
	: >"$BATS_TEST_TMPDIR/tool.log"
	run "${BASH:-bash}" "$cmd" -Force </dev/null
	restarted
}

@test "a refused restart request fails the command" {
	stub_tool osascript 'exit 1'
	run "${BASH:-bash}" "$cmd" --force </dev/null
	[ "$status" -ne 0 ]
	restarted
}

@test "a yes counts down before the restart; --force does not" {
	answers y
	run "${BASH:-bash}" "$cmd" </dev/null
	[ "$status" -eq 0 ]
	[[ $output == *"The Mac restarts in:"* ]]
	restarted
	: >"$BATS_TEST_TMPDIR/tool.log"
	run "${BASH:-bash}" "$cmd" --force </dev/null
	[[ $output != *"The Mac restarts in:"* ]]
	restarted
}

@test "--selection Yes restarts without the menu, No cancels, anything else is an error" {
	run "${BASH:-bash}" "$cmd" -Selection Yes </dev/null
	[ "$status" -eq 0 ]
	[[ $output != *"Do you want to restart"* ]]
	restarted
	: >"$BATS_TEST_TMPDIR/tool.log"
	answers y
	run "${BASH:-bash}" "$cmd" --selection no </dev/null
	[ "$status" -eq 0 ]
	! restarted || false
	run "${BASH:-bash}" "$cmd" --selection Maybe </dev/null
	[ "$status" -eq 1 ]
	! restarted || false
}

@test "--selection takes the menu numbers, as -Selection 1 does on Windows: 1 restarts, 2 cancels, 3 is an error" {
	run "${BASH:-bash}" "$cmd" --selection 2 </dev/null
	[ "$status" -eq 0 ]
	! restarted || false
	run "${BASH:-bash}" "$cmd" --selection 3 </dev/null
	[ "$status" -eq 1 ]
	! restarted || false
	run "${BASH:-bash}" "$cmd" --selection 1 </dev/null
	[ "$status" -eq 0 ]
	restarted
}
