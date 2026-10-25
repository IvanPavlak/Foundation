#!/usr/bin/env bats
# NpmInstallAndStart: runs npm in the current folder, arguments passed through; the second step runs even after the first fails, as on Windows.

load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_LOGGING=off
	cmd=$UNIX_DIR/modules/Helper/bin/NpmInstallAndStart
}

@test "runs npm with the arguments" {
	stub_tool npm
	cd "$BATS_TEST_TMPDIR"
	run "${BASH:-bash}" "$cmd" --urls http://localhost:5000
	[ "$status" -eq 0 ]
	grep -q '^npm install' "$BATS_TEST_TMPDIR/tool.log"
	grep -q 'http://localhost:5000' "$BATS_TEST_TMPDIR/tool.log"
}

@test "runs the second step even when the first fails, as on Windows" {
	stub_tool npm 'case "$1" in install) exit 3 ;; esac; exit 0'
	cd "$BATS_TEST_TMPDIR"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	grep -q '^npm install' "$BATS_TEST_TMPDIR/tool.log"
	grep -q '^npm start' "$BATS_TEST_TMPDIR/tool.log"
}

@test "a leading --help prints the header and never reaches npm; after -- it does" {
	stub_tool npm
	cd "$BATS_TEST_TMPDIR"
	run "${BASH:-bash}" "$cmd" --help
	[ "$status" -eq 0 ]
	[[ ${lines[0]} == "NpmInstallAndStart - "* ]]
	[ ! -e "$BATS_TEST_TMPDIR/tool.log" ]
	run "${BASH:-bash}" "$cmd" -- --help
	grep -qx 'npm start -- --help' "$BATS_TEST_TMPDIR/tool.log"
}
