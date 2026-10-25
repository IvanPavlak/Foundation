#!/usr/bin/env bats
# Clear-OldBackups: prunes by count, age and size, never the newest backup of a key, never a folder that
# is not a timestamp; --dry-run deletes nothing.

load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_LOGGING=off
	cmd=$UNIX_DIR/modules/Helper/bin/Clear-OldBackups
}

setup_sink() {
	export FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/sink
	for i in 1 2 3 4; do mkdir -p "$FOUNDATION_BACKUP_ROOT/Config/A/2026-0$i-01_10-00-00"; done
	mkdir -p "$FOUNDATION_BACKUP_ROOT/Config/Old/2020-01-01_10-00-00"
}

@test "per-key limit removes the oldest, the only backup of a key survives any limit" {
	setup_sink
	run "${BASH:-bash}" "$cmd" --max-backups-per-key 2 --max-age-days 365 --max-total-size-mb 0
	[ "$status" -eq 0 ]
	[ ! -d "$FOUNDATION_BACKUP_ROOT/Config/A/2026-01-01_10-00-00" ]
	[ ! -d "$FOUNDATION_BACKUP_ROOT/Config/A/2026-02-01_10-00-00" ]
	[ -d "$FOUNDATION_BACKUP_ROOT/Config/A/2026-04-01_10-00-00" ]
	[ -d "$FOUNDATION_BACKUP_ROOT/Config/Old/2020-01-01_10-00-00" ]
}

@test "--dry-run lists and deletes nothing" {
	setup_sink
	run "${BASH:-bash}" "$cmd" --dry-run --max-backups-per-key 1
	[[ $output == *"would remove"* ]]
	[ "$(find "$FOUNDATION_BACKUP_ROOT" -mindepth 3 -maxdepth 3 -type d | wc -l | tr -d ' ')" -eq 5 ]
}

@test "a folder that is not a timestamp is no backup: never the newest, never counted, never removed" {
	export FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/sink
	mkdir -p "$FOUNDATION_BACKUP_ROOT/Config/K/2020-01-01_00-00-01" "$FOUNDATION_BACKUP_ROOT/Config/K/2020-01-02_00-00-01" "$FOUNDATION_BACKUP_ROOT/Config/K/NotATimestamp"
	run "${BASH:-bash}" "$cmd" --max-backups-per-key 1 --max-age-days 1 --max-total-size-mb 0
	[ "$status" -eq 0 ]
	[ ! -d "$FOUNDATION_BACKUP_ROOT/Config/K/2020-01-01_00-00-01" ]
	[ -d "$FOUNDATION_BACKUP_ROOT/Config/K/2020-01-02_00-00-01" ]
	[ -d "$FOUNDATION_BACKUP_ROOT/Config/K/NotATimestamp" ]
}

@test "age limit removes the backups older than max-age-days and keeps the newest" {
	export FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/sink
	recent=$(date +%Y-%m-%d)_00-00-00
	mkdir -p "$FOUNDATION_BACKUP_ROOT/Config/A/2020-01-01_10-00-00" "$FOUNDATION_BACKUP_ROOT/Config/A/$recent" "$FOUNDATION_BACKUP_ROOT/Config/B/2020-01-01_10-00-00"
	run "${BASH:-bash}" "$cmd" --max-age-days 30 --max-backups-per-key 0 --max-total-size-mb 0
	[ "$status" -eq 0 ]
	[ ! -d "$FOUNDATION_BACKUP_ROOT/Config/A/2020-01-01_10-00-00" ]
	[ -d "$FOUNDATION_BACKUP_ROOT/Config/A/$recent" ]
	# The only backup of a key is its newest, however old.
	[ -d "$FOUNDATION_BACKUP_ROOT/Config/B/2020-01-01_10-00-00" ]
}

@test "size limit removes the oldest first while the sink is too large, never a key's newest" {
	export FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/sink
	for folder in A/2026-01-01_10-00-00 A/2026-02-01_10-00-00 A/2026-03-01_10-00-00 B/2026-01-15_10-00-00; do
		mkdir -p "$FOUNDATION_BACKUP_ROOT/Config/$folder"
		head -c 614400 /dev/urandom >"$FOUNDATION_BACKUP_ROOT/Config/$folder/data"
	done
	run "${BASH:-bash}" "$cmd" --max-total-size-mb 1 --max-age-days 0 --max-backups-per-key 0
	[ "$status" -eq 0 ]
	[ ! -d "$FOUNDATION_BACKUP_ROOT/Config/A/2026-01-01_10-00-00" ]
	[ ! -d "$FOUNDATION_BACKUP_ROOT/Config/A/2026-02-01_10-00-00" ]
	[ -d "$FOUNDATION_BACKUP_ROOT/Config/A/2026-03-01_10-00-00" ]
	[ -d "$FOUNDATION_BACKUP_ROOT/Config/B/2026-01-15_10-00-00" ]
}

@test "the limits of backups.conf apply without a flag" {
	setup_sink
	use_empty_config
	printf 'max-backups-per-key 1\nmax-total-size-mb 0\n' >"$FOUNDATION_CONFIG_DIR/backups.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(ls "$FOUNDATION_BACKUP_ROOT/Config/A")" = 2026-04-01_10-00-00 ]
	[ -d "$FOUNDATION_BACKUP_ROOT/Config/Old/2020-01-01_10-00-00" ]
}

@test "a limit that is no whole number and an unknown flag fail before anything is removed" {
	setup_sink
	run "${BASH:-bash}" "$cmd" --max-age-days x --max-backups-per-key 1
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" --max-backups-per-key 1 --bogus
	[ "$status" -ne 0 ]
	[ "$(find "$FOUNDATION_BACKUP_ROOT" -mindepth 3 -maxdepth 3 -type d | wc -l | tr -d ' ')" -eq 5 ]
}

@test "a missing sink succeeds and removes nothing" {
	export FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/no-sink
	run "${BASH:-bash}" "$cmd" --max-backups-per-key 1
	[ "$status" -eq 0 ]
	[[ $output == *"No backups yet"* ]]
	[ ! -e "$FOUNDATION_BACKUP_ROOT" ]
}
