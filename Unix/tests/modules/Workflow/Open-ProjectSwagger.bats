#!/usr/bin/env bats
# Open-ProjectSwagger against the platform and browser stand-ins: a project's [Swagger] entry opens
# through Open-Browser, and nothing opens without a project, without an entry, or while the tab is
# open: the entry's own tab while its backend answers (nc, a stand-in that answers by default),
# any failed-load window of the browser while it does not.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	stub_config
	printf '\n[Swagger]\nSampleApi https://localhost:5001/swagger\nOtherApi https://localhost:5002/swagger\n' >>"$FOUNDATION_CONFIG_DIR/browser-groups.conf"
	cmd=$UNIX_DIR/modules/Workflow/bin/Open-ProjectSwagger
	stub_tool nc 'exit 0'
}

@test "a project's Swagger entry opens in the browser" {
	run "${BASH:-bash}" "$cmd" SampleApi
	[ "$status" -eq 0 ]
	stub_wait_for '^launch Firefox .*https://localhost:5001/swagger'
	! stub_called 'localhost:5002' || false
}

@test "the project name matches the entry case-insensitively" {
	run "${BASH:-bash}" "$cmd" sampleapi
	[ "$status" -eq 0 ]
	stub_wait_for '^launch Firefox .*https://localhost:5001/swagger'
}

@test "no project does nothing at all" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -s "$STUB_LOG" ]
}

@test "a project without a Swagger entry opens nothing" {
	run "${BASH:-bash}" "$cmd" NoSuchProjectAnywhere
	[ "$status" -eq 0 ]
	! stub_called '^launch' || false
}

@test "backend up: the project's own tab skips a rerun, the probe names the entry's host and port" {
	run "${BASH:-bash}" "$cmd" SampleApi
	stub_wait_for '^launch Firefox .*https://localhost:5001/swagger'
	grep -q 'nc .*localhost 5001$' "$BATS_TEST_TMPDIR/tool.log"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" SampleApi
	[ "$status" -eq 0 ]
	[[ $output == *"already open"* ]]
	! stub_called '^launch' || false
}

@test "backend up: another project's open Swagger UI does not skip this project's tab" {
	stub_window 50 org.mozilla.firefox 1 Firefox "Swagger UI - Mozilla Firefox"
	run "${BASH:-bash}" "$cmd" OtherApi
	[ "$status" -eq 0 ]
	stub_wait_for '^launch Firefox .*https://localhost:5002/swagger'
}

@test "backend down: a failed-load window of the browser skips the open, none opens the tab" {
	stub_tool nc 'exit 1'
	stub_window 50 org.mozilla.firefox 1 Firefox "Problem loading page - Mozilla Firefox"
	run "${BASH:-bash}" "$cmd" SampleApi
	[ "$status" -eq 0 ]
	[[ $output == *"backend is down"* ]]
	! stub_called '^launch' || false
	: >"$STUB_WINDOWS"
	stub_window 51 com.microsoft.VSCode 1 Code "Problem loading page notes"
	run "${BASH:-bash}" "$cmd" SampleApi
	[ "$status" -eq 0 ]
	stub_wait_for '^launch Firefox .*https://localhost:5001/swagger'
}

@test "backend down: the failed-load text comes from problem-page-title of window.conf" {
	stub_tool nc 'exit 1'
	echo 'problem-page-title  Seite kann nicht geladen werden' >>"$FOUNDATION_CONFIG_DIR/window.conf"
	stub_window 50 org.mozilla.firefox 1 Firefox "Problem loading page"
	run "${BASH:-bash}" "$cmd" SampleApi
	stub_wait_for '^launch Firefox .*https://localhost:5001/swagger'
	: >"$STUB_LOG"
	: >"$STUB_WINDOWS"
	stub_window 50 org.mozilla.firefox 1 Firefox "Seite kann nicht geladen werden"
	run "${BASH:-bash}" "$cmd" SampleApi
	! stub_called '^launch' || false
}

@test "--browser checks and opens in that browser" {
	stub_tool nc 'exit 1'
	stub_window 50 org.mozilla.firefox 1 Firefox "Problem loading page"
	run "${BASH:-bash}" "$cmd" SampleApi --browser Chrome
	[ "$status" -eq 0 ]
	stub_wait_for '^launch Chrome .*https://localhost:5001/swagger'
	! stub_called '^launch Firefox' || false
}

@test "only the first project is used, as on Windows" {
	run "${BASH:-bash}" "$cmd" OtherApi SampleApi
	[ "$status" -eq 0 ]
	stub_wait_for '^launch Firefox .*https://localhost:5002/swagger'
	! stub_called 'localhost:5001' || false
}

@test "a comma list names projects, as -Project A,B does (A is used); an unknown flag opens nothing" {
	run "${BASH:-bash}" "$cmd" -Project SampleApi,OtherApi
	[ "$status" -eq 0 ]
	stub_wait_for '^launch Firefox .*https://localhost:5001/swagger'
	! stub_called 'localhost:5002' || false
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" SampleApi --bogus
	[ "$status" -eq 1 ]
	! stub_called '^launch' || false
}
