#!/usr/bin/env bats
# lib/spinner.sh: spinner_stop leaves the check mark and clears its state, --discard leaves nothing,
# a second stop is a no-op; spinner_start draws nothing without a terminal or at the quiet level.
# The spinner process is a stand-in sleep, never a drawing loop.

load helpers

setup() {
	setup_foundation
	foundation_load spinner
	unset NO_COLOR LOG_FORCE_COLOR
}

# A stand-in spinner process (fd 3 closed, so bats does not wait for it).
fake_spinner() {
	sleep 30 3>&- &
	SPINNER_PID=$!
	SPINNER_LABEL=Work
}

@test "spinner_stop leaves the check mark, ends the process and clears its state; a second stop is a no-op" {
	fake_spinner
	pid=$SPINNER_PID
	spinner_stop 2>"$BATS_TEST_TMPDIR/stderr"
	[[ $(cat "$BATS_TEST_TMPDIR/stderr") == *" ✓ Work"* ]]
	[ -z "$SPINNER_PID" ]
	[ -z "$SPINNER_LABEL" ]
	! kill -0 "$pid" 2>/dev/null || false
	spinner_stop 2>"$BATS_TEST_TMPDIR/stderr"
	[ ! -s "$BATS_TEST_TMPDIR/stderr" ]
}

@test "spinner_stop --discard ends the process and prints nothing" {
	fake_spinner
	pid=$SPINNER_PID
	spinner_stop --discard 2>"$BATS_TEST_TMPDIR/stderr"
	[ ! -s "$BATS_TEST_TMPDIR/stderr" ]
	[ -z "$SPINNER_PID" ]
	[ -z "$SPINNER_LABEL" ]
	! kill -0 "$pid" 2>/dev/null || false
}

@test "spinner_start starts nothing without a terminal or at the quiet level" {
	spinner_start Work 2>"$BATS_TEST_TMPDIR/stderr"
	[ -z "${SPINNER_PID:-}" ]
	[ ! -s "$BATS_TEST_TMPDIR/stderr" ]
	FOUNDATION_LOG_LEVEL=quiet spinner_start Work 2>"$BATS_TEST_TMPDIR/stderr"
	[ -z "${SPINNER_PID:-}" ]
}
