#!/usr/bin/env bats
# Countdown: counts down and succeeds; a missing or non-numeric count fails.

load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_LOGGING=off
	cmd=$UNIX_DIR/modules/Helper/bin/Countdown
}

@test "a count finishes with status 0" {
	run "${BASH:-bash}" "$cmd" 1 --message "Soon"
	[ "$status" -eq 0 ]
	[[ $output == *Soon* ]]
}

@test "a missing or non-numeric count fails" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" abc
	[ "$status" -ne 0 ]
}
