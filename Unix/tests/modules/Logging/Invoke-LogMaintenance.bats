#!/usr/bin/env bats
# Invoke-LogMaintenance: a due sweep applies the log, backup and test-results retention, silently,
# and writes its stamp; a fresh stamp or maintenance off skips it, --force runs it anyway; the
# background retention of a new session runs it when it is due. Every folder is a throwaway one.

load ../../helpers

setup() {
	setup_foundation
	use_empty_config
	export FOUNDATION_LOGGING=off
	export FOUNDATION_LOG_DIR=$BATS_TEST_TMPDIR/logs FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/backups
	export FOUNDATION_TEST_RESULTS=$BATS_TEST_TMPDIR/results TMPDIR=$BATS_TEST_TMPDIR/tmp
	mkdir -p "$FOUNDATION_LOG_DIR" "$FOUNDATION_TEST_RESULTS" "$TMPDIR"
	stamp=$FOUNDATION_LOG_DIR/.last-maintenance
	cmd=$UNIX_DIR/modules/Logging/bin/Invoke-LogMaintenance
}

# Twelve run logs two years old, plus the files the results retention never touches.
old_results() {
	for i in $(seq -w 1 12); do : >"$FOUNDATION_TEST_RESULTS/TestRun_202401${i}_000000_1.log"; done
	: >"$FOUNDATION_TEST_RESULTS/suite-timings.tsv"
	touch -t 202401010000 "$FOUNDATION_TEST_RESULTS"/*
}

run_logs() {
	local logs=("$FOUNDATION_TEST_RESULTS"/TestRun_*.log)
	printf '%s' "${#logs[@]}"
}

@test "a due sweep prunes logs, backups and test results, prints nothing and writes the stamp" {
	printf 'max-session-files 2\n' >"$FOUNDATION_CONFIG_DIR/logging.conf"
	printf 'max-backups-per-key 1\n' >"$FOUNDATION_CONFIG_DIR/backups.conf"
	for i in 1 2 3; do : >"$FOUNDATION_LOG_DIR/Session_2026-01-0${i}_00-00-00_X.log"; done
	mkdir -p "$FOUNDATION_BACKUP_ROOT/Dotfiles/Key/2026-01-01_00-00-00" "$FOUNDATION_BACKUP_ROOT/Dotfiles/Key/2026-01-02_00-00-00"
	old_results
	mkdir -p "$TMPDIR/foundation-tests.abandoned" "$TMPDIR/foundation-tests.live"
	touch -t 202401010000 "$TMPDIR/foundation-tests.abandoned"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	[ -f "$stamp" ]
	[ ! -e "$FOUNDATION_LOG_DIR/Session_2026-01-01_00-00-00_X.log" ]
	[ ! -e "$FOUNDATION_BACKUP_ROOT/Dotfiles/Key/2026-01-01_00-00-00" ]
	[ -d "$FOUNDATION_BACKUP_ROOT/Dotfiles/Key/2026-01-02_00-00-00" ]
	[ "$(run_logs)" -eq 10 ]
	[ ! -e "$FOUNDATION_TEST_RESULTS/TestRun_20240101_000000_1.log" ]
	[ -f "$FOUNDATION_TEST_RESULTS/TestRun_20240112_000000_1.log" ]
	[ -f "$FOUNDATION_TEST_RESULTS/suite-timings.tsv" ]
	[ ! -e "$TMPDIR/foundation-tests.abandoned" ]
	[ -d "$TMPDIR/foundation-tests.live" ]
}

@test "a fresh stamp or maintenance off skips the sweep; --force runs it anyway" {
	old_results
	: >"$stamp"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(run_logs)" -eq 12 ]
	printf 'maintenance off\n' >"$FOUNDATION_CONFIG_DIR/logging.conf"
	touch -t 202401010000 "$stamp"
	run "${BASH:-bash}" "$cmd"
	[ "$(run_logs)" -eq 12 ]
	run "${BASH:-bash}" "$cmd" --force
	[ "$status" -eq 0 ]
	[ "$(run_logs)" -eq 10 ]
}

@test "maintenance-interval-hours sets the throttle; --results-directory prunes another folder" {
	other=$BATS_TEST_TMPDIR/other-results
	mkdir -p "$other"
	for i in $(seq -w 1 11); do : >"$other/TestRun_202401${i}_000000_1.log"; done
	touch -t 202401010000 "$other"/*
	# A stamp two hours old: due under a one-hour interval, not under the default 24.
	touch -t "$(date -v-2H +%Y%m%d%H%M)" "$stamp"
	run "${BASH:-bash}" "$cmd" --results-directory "$other"
	[ "$status" -eq 0 ]
	[ -f "$other/TestRun_20240101_000000_1.log" ]
	printf 'maintenance-interval-hours 1\n' >"$FOUNDATION_CONFIG_DIR/logging.conf"
	run "${BASH:-bash}" "$cmd" --results-directory "$other"
	[ "$status" -eq 0 ]
	[ ! -e "$other/TestRun_20240101_000000_1.log" ]
	[ -f "$other/TestRun_20240102_000000_1.log" ]
}

@test "a new session's background retention runs the sweep when it is due, not before" {
	old_results
	: >"$stamp"
	logfile__background
	[ "$(run_logs)" -eq 12 ]
	touch -t 202401010000 "$stamp"
	logfile__background
	[ "$(run_logs)" -eq 10 ]
	[ -n "$(find "$stamp" -mmin -5)" ]
}
