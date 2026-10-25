#!/usr/bin/env bats
# Protect-Log: copies the newest session log, the newest of a command (aliases too), a given file
# or a timestamped snapshot of Errors.log into Pinned, leaving the original in place.

load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_LOGGING=off FOUNDATION_LOG_DIR=$BATS_TEST_TMPDIR/logs
	mkdir -p "$FOUNDATION_LOG_DIR"
	printf 'workspace\n' >"$FOUNDATION_LOG_DIR/Session_2026-01-01_10-00-00_Open-Workspace.log"
	printf 'kill\n' >"$FOUNDATION_LOG_DIR/Session_2026-01-02_10-00-00_Kill-All.log"
	cmd=$UNIX_DIR/modules/Logging/bin/Protect-Log
}

@test "without an argument the newest session log is pinned and the original stays" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(cat "$FOUNDATION_LOG_DIR/Pinned/Session_2026-01-02_10-00-00_Kill-All.log")" = kill ]
	[ -f "$FOUNDATION_LOG_DIR/Session_2026-01-02_10-00-00_Kill-All.log" ]
	[ "$(find "$FOUNDATION_LOG_DIR/Pinned" -type f | grep -c .)" -eq 1 ]
}

@test "a command name or alias pins its newest log, a path pins that file" {
	run "${BASH:-bash}" "$cmd" w
	[ "$status" -eq 0 ]
	[ -f "$FOUNDATION_LOG_DIR/Pinned/Session_2026-01-01_10-00-00_Open-Workspace.log" ]
	printf 'mine\n' >"$BATS_TEST_TMPDIR/custom.log"
	run "${BASH:-bash}" "$cmd" "$BATS_TEST_TMPDIR/custom.log"
	[ "$status" -eq 0 ]
	[ "$(cat "$FOUNDATION_LOG_DIR/Pinned/custom.log")" = mine ]
}

@test "--error-log pins a timestamped snapshot; without Errors.log it warns, an unknown command fails" {
	run "${BASH:-bash}" "$cmd" --error-log
	[ "$status" -eq 0 ]
	[[ $output == *"No log file to pin at"* ]]
	printf 'boom\n' >"$FOUNDATION_LOG_DIR/Errors.log"
	run "${BASH:-bash}" "$cmd" --error-log
	[ "$status" -eq 0 ]
	[ "$(cat "$FOUNDATION_LOG_DIR"/Pinned/Errors_*.log)" = boom ]
	run "${BASH:-bash}" "$cmd" NoSuchCommand
	[ "$status" -ne 0 ]
}

@test "a missing PATH warns and exits 0 as on Windows, never looked up as a command" {
	run "${BASH:-bash}" "$cmd" "$BATS_TEST_TMPDIR/missing.log"
	[ "$status" -eq 0 ]
	[[ $output == *"No log file to pin at"* ]]
	[[ $output != *"No session log"* ]]
	run "${BASH:-bash}" "$cmd" logs/Open-Workspace
	[ "$status" -eq 0 ]
	[[ $output == *"No log file to pin at"* ]]
	[ ! -d "$FOUNDATION_LOG_DIR/Pinned" ] || [ -z "$(ls -A "$FOUNDATION_LOG_DIR/Pinned")" ]
}

@test "--errors is the --error-log alias" {
	printf 'boom\n' >"$FOUNDATION_LOG_DIR/Errors.log"
	run "${BASH:-bash}" "$cmd" --errors
	[ "$status" -eq 0 ]
	[ "$(cat "$FOUNDATION_LOG_DIR"/Pinned/Errors_*.log)" = boom ]
}

@test "--error-log pins the error-file of logging.conf, its snapshot named after it" {
	use_empty_config
	printf 'error-file Failures.log\n' >"$FOUNDATION_CONFIG_DIR/logging.conf"
	printf 'bang\n' >"$FOUNDATION_LOG_DIR/Failures.log"
	run "${BASH:-bash}" "$cmd" --error-log
	[ "$status" -eq 0 ]
	[ "$(cat "$FOUNDATION_LOG_DIR"/Pinned/Failures_*.log)" = bang ]
}
