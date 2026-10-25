#!/usr/bin/env bats
# DotnetRun: runs dotnet in the current folder, arguments passed through; the second step only after the first succeeds.

load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_LOGGING=off
	cmd=$UNIX_DIR/modules/Helper/bin/DotnetRun
}

@test "runs dotnet with the arguments" {
	stub_tool dotnet
	cd "$BATS_TEST_TMPDIR"
	run "${BASH:-bash}" "$cmd" --urls http://localhost:5000
	[ "$status" -eq 0 ]
	grep -q '^dotnet run' "$BATS_TEST_TMPDIR/tool.log"
	grep -q 'http://localhost:5000' "$BATS_TEST_TMPDIR/tool.log"
}

@test "a leading --help prints the header and never reaches dotnet; after -- it does" {
	stub_tool dotnet
	cd "$BATS_TEST_TMPDIR"
	run "${BASH:-bash}" "$cmd" --help
	[ "$status" -eq 0 ]
	[[ ${lines[0]} == "DotnetRun - "* ]]
	[ ! -e "$BATS_TEST_TMPDIR/tool.log" ]
	run "${BASH:-bash}" "$cmd" -- --help
	grep -qx 'dotnet run -- --help' "$BATS_TEST_TMPDIR/tool.log"
}
