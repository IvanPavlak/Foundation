#!/usr/bin/env bats
# The unified backup sink: Backup-RepositoryItem semantics (copy, skip-never-destroy, per-key
# pruning with the newest kept) against a throwaway sink.

load helpers

setup() {
	setup_foundation
	foundation_load backup
	export FOUNDATION_BACKUP_ROOT="$BATS_TEST_TMPDIR/sink"
}

@test "backup_item copies into Category/Key/timestamp and leaves the original" {
	echo data >"$BATS_TEST_TMPDIR/file.conf"
	folder=$(backup_item Config MyKey "$BATS_TEST_TMPDIR/file.conf")
	[[ $folder == "$FOUNDATION_BACKUP_ROOT/Config/MyKey/"[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_* ]]
	[ "$(cat "$folder/file.conf")" = data ]
	[ -f "$BATS_TEST_TMPDIR/file.conf" ]
}

@test "backup_item: two backups in one second get separate folders" {
	echo a >"$BATS_TEST_TMPDIR/f"
	one=$(backup_item Config K "$BATS_TEST_TMPDIR/f")
	two=$(backup_item Config K "$BATS_TEST_TMPDIR/f")
	[ "$one" != "$two" ]
	[ -f "$one/f" ]
	[ -f "$two/f" ]
}

@test "backup_item: a missing path fails and leaves no folder" {
	run backup_item Config K "$BATS_TEST_TMPDIR/missing"
	[ "$status" -ne 0 ]
	[ ! -d "$FOUNDATION_BACKUP_ROOT/Config/K" ] || [ -z "$(ls -A "$FOUNDATION_BACKUP_ROOT/Config/K")" ]
}

@test "backup_prune_key keeps the newest max-backups-per-key" {
	for i in 1 2 3 4 5 6 7 8 9 10 11 12; do mkdir -p "$FOUNDATION_BACKUP_ROOT/Config/K/2026-01-$(printf %02d "$i")_00-00-00"; done
	backup_prune_key "$FOUNDATION_BACKUP_ROOT/Config/K" >/dev/null
	[ "$(ls "$FOUNDATION_BACKUP_ROOT/Config/K" | wc -l | tr -d ' ')" -eq 10 ]
	[ -d "$FOUNDATION_BACKUP_ROOT/Config/K/2026-01-12_00-00-00" ]
	[ ! -d "$FOUNDATION_BACKUP_ROOT/Config/K/2026-01-01_00-00-00" ]
}

@test "backup_prune_key counts and removes only timestamp folders" {
	for i in 01 02 03 04 05 06 07 08 09 10; do mkdir -p "$FOUNDATION_BACKUP_ROOT/Config/K/2026-01-${i}_00-00-00"; done
	mkdir -p "$FOUNDATION_BACKUP_ROOT/Config/K/NotATimestamp"
	backup_prune_key "$FOUNDATION_BACKUP_ROOT/Config/K" >/dev/null
	[ -d "$FOUNDATION_BACKUP_ROOT/Config/K/2026-01-01_00-00-00" ]
	[ -d "$FOUNDATION_BACKUP_ROOT/Config/K/NotATimestamp" ]
	mkdir -p "$FOUNDATION_BACKUP_ROOT/Config/K/2026-01-11_00-00-00"
	backup_prune_key "$FOUNDATION_BACKUP_ROOT/Config/K" >/dev/null
	[ ! -d "$FOUNDATION_BACKUP_ROOT/Config/K/2026-01-01_00-00-00" ]
	[ -d "$FOUNDATION_BACKUP_ROOT/Config/K/NotATimestamp" ]
}

@test "backup_item copies a directory with its nested files, a link kept as a link" {
	mkdir -p "$BATS_TEST_TMPDIR/dir/nested"
	echo inner >"$BATS_TEST_TMPDIR/dir/nested/file"
	ln -s nested/file "$BATS_TEST_TMPDIR/dir/link"
	folder=$(backup_item SymbolicLinks Dir "$BATS_TEST_TMPDIR/dir")
	[ "$(cat "$folder/dir/nested/file")" = inner ]
	[ -L "$folder/dir/link" ]
	[ "$(readlink "$folder/dir/link")" = nested/file ]
}

@test "backup_item: a sink that cannot be created or a failed copy fails, prints no folder and leaves none" {
	echo data >"$BATS_TEST_TMPDIR/f"
	# A regular file where the sink's folder goes: mkdir fails.
	: >"$BATS_TEST_TMPDIR/not-a-folder"
	out=$(FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/not-a-folder backup_item Config K "$BATS_TEST_TMPDIR/f" 2>/dev/null) && false
	[ -z "$out" ]
	[ ! -s "$BATS_TEST_TMPDIR/not-a-folder" ]
	# A cp that fails after the folder was made: the half-taken folder is removed.
	stub_tool cp 'exit 1'
	out=$(backup_item Config K "$BATS_TEST_TMPDIR/f" 2>/dev/null) && false
	[ -z "$out" ]
	[ -z "$(find "$FOUNDATION_BACKUP_ROOT" -mindepth 3 2>/dev/null)" ]
	[ "$(cat "$BATS_TEST_TMPDIR/f")" = data ]
}

@test "backup_prune_key: max-backups-per-key 0 keeps every backup" {
	use_empty_config
	echo 'max-backups-per-key 0' >"$FOUNDATION_CONFIG_DIR/backups.conf"
	for i in 01 02 03 04 05 06 07 08 09 10 11 12; do mkdir -p "$FOUNDATION_BACKUP_ROOT/Config/K/2026-01-${i}_00-00-00"; done
	backup_prune_key "$FOUNDATION_BACKUP_ROOT/Config/K" >/dev/null
	[ "$(ls "$FOUNDATION_BACKUP_ROOT/Config/K" | wc -l | tr -d ' ')" -eq 12 ]
}

@test "backup_prune_key prunes only the key it is given" {
	for i in 01 02 03 04 05 06 07 08 09 10 11 12; do mkdir -p "$FOUNDATION_BACKUP_ROOT/Config/A/2026-01-${i}_00-00-00" "$FOUNDATION_BACKUP_ROOT/Config/B/2026-01-${i}_00-00-00"; done
	backup_prune_key "$FOUNDATION_BACKUP_ROOT/Config/A" >/dev/null
	[ "$(ls "$FOUNDATION_BACKUP_ROOT/Config/A" | wc -l | tr -d ' ')" -eq 10 ]
	[ "$(ls "$FOUNDATION_BACKUP_ROOT/Config/B" | wc -l | tr -d ' ')" -eq 12 ]
}
