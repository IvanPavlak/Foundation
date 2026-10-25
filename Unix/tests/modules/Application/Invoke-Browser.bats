#!/usr/bin/env bats
# Invoke-Browser against the platform and browser stand-ins: a query becomes a Google search in a
# new window, a bare call is the Open-Browser group menu (an empty Enter opens a plain window).

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	stub_config
	cmd=$UNIX_DIR/modules/Application/bin/Invoke-Browser
}

@test "a query is searched on Google in a new window of the default browser" {
	run "${BASH:-bash}" "$cmd" how to x
	[ "$status" -eq 0 ]
	stub_wait_for '^launch Firefox -new-window https://www\.google\.com/search\?q=how\+to\+x$'
}

@test "without a query the group menu is shown: an empty Enter opens a plain window" {
	printf '\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_wait_for '^launch Firefox -new-window$'
	! stub_called 'google\.com' || false
}

@test "without a query and without a terminal nothing opens" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	! stub_called '^launch' || false
}

@test "--help prints the usage and opens nothing" {
	run "${BASH:-bash}" "$cmd" --help
	[ "$status" -eq 0 ]
	[[ $output == *"Usage: Invoke-Browser"* ]]
	! stub_called '^launch' || false
}

@test "a leading Windows -Query is dropped; a query that is the word query stays" {
	run "${BASH:-bash}" "$cmd" -Query how to x
	[ "$status" -eq 0 ]
	stub_wait_for '^launch Firefox -new-window https://www\.google\.com/search\?q=how\+to\+x$'
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" query plan
	stub_wait_for 'search\?q=query\+plan$'
}
