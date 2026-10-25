#!/usr/bin/env bats
# Clear-OldLogs: applies the session retention, --dry-run deletes nothing, Pinned survives, the
# limit flags override logging.conf for one run.

load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_LOGGING=off
	cmd=$UNIX_DIR/modules/Logging/bin/Clear-OldLogs
}

@test "--dry-run lists, a real run keeps the newest sessions and Pinned" {
	export FOUNDATION_LOG_DIR=$BATS_TEST_TMPDIR/logs
	mkdir -p "$FOUNDATION_LOG_DIR/Pinned"
	for i in $(seq -w 1 22); do : >"$FOUNDATION_LOG_DIR/Session_2026-01-${i}_00-00-00_X.log"; done
	: >"$FOUNDATION_LOG_DIR/Pinned/Session_2020-01-01_00-00-00_Keep.log"
	run "${BASH:-bash}" "$cmd" --dry-run
	[[ $output == *"would remove"* ]]
	[ "$(ls "$FOUNDATION_LOG_DIR" | grep -c '^Session_')" -eq 22 ]
	run "${BASH:-bash}" "$cmd"
	[ "$(ls "$FOUNDATION_LOG_DIR" | grep -c '^Session_')" -eq 20 ]
	[ -f "$FOUNDATION_LOG_DIR/Pinned/Session_2020-01-01_00-00-00_Keep.log" ]
}

@test "Errors.log past the cap is trimmed to half of it, as --dry-run and --what-if say" {
	use_empty_config
	printf 'max-error-file-size-mb 1\n' >"$FOUNDATION_CONFIG_DIR/logging.conf"
	export FOUNDATION_LOG_DIR=$BATS_TEST_TMPDIR/logs
	mkdir -p "$FOUNDATION_LOG_DIR"
	head -c 1500000 /dev/zero | tr '\0' x >"$FOUNDATION_LOG_DIR/Errors.log"
	run "${BASH:-bash}" "$cmd" --dry-run
	[[ $output == *"would trim Errors.log to its newest 512 KB (half of max-error-file-size-mb 1)"* ]]
	run "${BASH:-bash}" "$cmd" --what-if
	[[ $output == *"would trim Errors.log to its newest 512 KB"* ]]
	[ "$(wc -c <"$FOUNDATION_LOG_DIR/Errors.log" | tr -d ' ')" -eq 1500000 ]
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"trimmed Errors.log to its newest 512 KB"* ]]
	[ "$(wc -c <"$FOUNDATION_LOG_DIR/Errors.log" | tr -d ' ')" -eq 524288 ]
}

@test "logging.conf honours @TYPE lines, -LINE removals and the overlay, the last line winning" {
	use_empty_config
	export FOUNDATION_MACHINE_TYPE=Work FOUNDATION_LOG_DIR=$BATS_TEST_TMPDIR/logs
	mkdir -p "$FOUNDATION_LOG_DIR"
	head -c 1500000 /dev/zero | tr '\0' x >"$FOUNDATION_LOG_DIR/Errors.log"
	# The cap of this machine type is 1 MB: the 1.5 MB log is trimmed.
	printf 'max-error-file-size-mb 5\n@Work max-error-file-size-mb 1\n@Laptop max-error-file-size-mb 9\n' >"$FOUNDATION_CONFIG_DIR/logging.conf"
	run "${BASH:-bash}" "$cmd" --dry-run
	[[ $output == *"would trim Errors.log to its newest 512 KB"* ]]
	# Another machine type's line does not apply: the 5 MB cap leaves it alone.
	printf 'max-error-file-size-mb 5\n@Laptop max-error-file-size-mb 1\n' >"$FOUNDATION_CONFIG_DIR/logging.conf"
	run "${BASH:-bash}" "$cmd" --dry-run
	[[ $output != *"would trim"* ]]
	# The overlay's -LINE takes the base 5 back and its own line sets 1.
	printf 'max-error-file-size-mb 5\n' >"$FOUNDATION_CONFIG_DIR/logging.conf"
	printf -- '-max-error-file-size-mb   5\nmax-error-file-size-mb 1\n' >"$FOUNDATION_CONFIG_DIR/logging.local.conf"
	run "${BASH:-bash}" "$cmd" --dry-run
	[[ $output == *"would trim Errors.log to its newest 512 KB"* ]]
	# Removed with nothing in its place, the key falls back to the base value 5.
	printf -- '-max-error-file-size-mb 5\n' >"$FOUNDATION_CONFIG_DIR/logging.local.conf"
	run "${BASH:-bash}" "$cmd" --dry-run
	[[ $output != *"would trim"* ]]
}

@test "the limit flags override logging.conf for one run, Windows spelling too; a limit that is no number is refused" {
	export FOUNDATION_LOG_DIR=$BATS_TEST_TMPDIR/logs
	mkdir -p "$FOUNDATION_LOG_DIR"
	for i in $(seq -w 1 12); do : >"$FOUNDATION_LOG_DIR/Session_2026-01-${i}_00-00-00_X.log"; done
	head -c 1500000 /dev/zero | tr '\0' x >"$FOUNDATION_LOG_DIR/Errors.log"
	run "${BASH:-bash}" "$cmd" --dry-run --max-session-files 5 --max-error-file-size-mb 1
	[ "$status" -eq 0 ]
	[ "$(grep -c 'more than 5 sessions' <<<"$output")" -eq 7 ]
	[[ $output == *"would trim Errors.log to its newest 512 KB (half of max-error-file-size-mb 1)"* ]]
	run "${BASH:-bash}" "$cmd" -MaxSessionFiles 5
	[ "$status" -eq 0 ]
	sessions=("$FOUNDATION_LOG_DIR"/Session_*.log)
	[ ${#sessions[@]} -eq 5 ]
	[ -f "$FOUNDATION_LOG_DIR/Session_2026-01-12_00-00-00_X.log" ]
	# The fixture's max-session-files 20 applies again on the next run.
	run "${BASH:-bash}" "$cmd" --dry-run
	[[ $output != *"more than"* ]]
	run "${BASH:-bash}" "$cmd" --max-session-files
	[ "$status" -eq 1 ]
	[[ $output == *"--max-session-files takes a whole number (0 = off)"* ]]
	run "${BASH:-bash}" "$cmd" --max-age-days seven
	[ "$status" -eq 1 ]
	sessions=("$FOUNDATION_LOG_DIR"/Session_*.log)
	[ ${#sessions[@]} -eq 5 ]
}
