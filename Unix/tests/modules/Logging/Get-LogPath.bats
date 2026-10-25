#!/usr/bin/env bats
# Get-LogPath: the newest session log, per command or alias, the error log, the folder.

load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_LOGGING=off
	cmd=$UNIX_DIR/modules/Logging/bin/Get-LogPath
}

@test "newest overall, newest of a command (aliases too), errors and folder" {
	export FOUNDATION_LOG_DIR=$BATS_TEST_TMPDIR/logs
	mkdir -p "$FOUNDATION_LOG_DIR"
	touch "$FOUNDATION_LOG_DIR/Session_2026-01-01_10-00-00_Open-Workspace.log" "$FOUNDATION_LOG_DIR/Session_2026-01-02_10-00-00_Kill-All.log" "$FOUNDATION_LOG_DIR/Errors.log"
	run "${BASH:-bash}" "$cmd"
	[ "$output" = "$FOUNDATION_LOG_DIR/Session_2026-01-02_10-00-00_Kill-All.log" ]
	run "${BASH:-bash}" "$cmd" w
	[ "$output" = "$FOUNDATION_LOG_DIR/Session_2026-01-01_10-00-00_Open-Workspace.log" ]
	run "${BASH:-bash}" "$cmd" --errors
	[ "$output" = "$FOUNDATION_LOG_DIR/Errors.log" ]
	run "${BASH:-bash}" "$cmd" --directory
	[ "$output" = "$FOUNDATION_LOG_DIR" ]
	run "${BASH:-bash}" "$cmd" NoSuchCommand
	[ "$status" -ne 0 ]
}

@test "--error-log (the Windows -ErrorLog) prints Errors.log; an unknown flag is an error, not a command" {
	export FOUNDATION_LOG_DIR=$BATS_TEST_TMPDIR/logs
	mkdir -p "$FOUNDATION_LOG_DIR"
	touch "$FOUNDATION_LOG_DIR/Session_2026-01-01_10-00-00_Open-Workspace.log" "$FOUNDATION_LOG_DIR/Errors.log"
	run "${BASH:-bash}" "$cmd" --error-log
	[ "$status" -eq 0 ]
	[ "$output" = "$FOUNDATION_LOG_DIR/Errors.log" ]
	run "${BASH:-bash}" "$cmd" -ErrorLog
	[ "$output" = "$FOUNDATION_LOG_DIR/Errors.log" ]
	run "${BASH:-bash}" "$cmd" --no-such-flag
	[ "$status" -ne 0 ]
	[[ $output == *"Unknown argument => --no-such-flag"* ]]
	[[ $output != *"No session log"* ]]
}

@test "--errors and --directory follow the error-file and directory of logging.conf" {
	use_empty_config
	unset FOUNDATION_LOG_DIR
	printf 'directory %s\nerror-file Failures.log\n' "$BATS_TEST_TMPDIR/elsewhere" >"$FOUNDATION_CONFIG_DIR/logging.conf"
	mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
	run "${BASH:-bash}" "$cmd" --directory
	[ "$output" = "$BATS_TEST_TMPDIR/elsewhere" ]
	run "${BASH:-bash}" "$cmd" --errors
	[ "$status" -ne 0 ]
	: >"$BATS_TEST_TMPDIR/elsewhere/Failures.log"
	run "${BASH:-bash}" "$cmd" --errors
	[ "$status" -eq 0 ]
	[ "$output" = "$BATS_TEST_TMPDIR/elsewhere/Failures.log" ]
}
