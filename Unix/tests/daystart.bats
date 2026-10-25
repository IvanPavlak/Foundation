#!/usr/bin/env bats
# The day boundary of the daily startup repository update (Get-RepositoryUpdateDayStart on
# Windows): today at the start hour, yesterday at it before that hour. `date` is replaced by a
# fixed clock: epoch 1000000 at the time of day each test names.

load helpers

setup() {
	setup_foundation
	. "$UNIX_DIR/lib/daystart.sh"
}

# The fixed clock. Usage: at HH MM SS
at() {
	clock="1000000 $1 $2 $3"
	date() { printf '%s\n' "$clock"; }
}

@test "after the start hour the day began today" {
	at 08 09 09
	[ "$(foundation_day_start 6)" -eq $((1000000 - (2 * 3600 + 9 * 60 + 9))) ]
}

@test "before the start hour the day began yesterday, so late-night work stays on that day" {
	at 05 59 00
	[ "$(foundation_day_start 6)" -eq $((1000000 - (23 * 3600 + 59 * 60))) ]
}

@test "the start hour itself is the new day" {
	at 06 00 00
	[ "$(foundation_day_start 6)" -eq 1000000 ]
}

@test "hour 0 is plain midnight, and leading zeros are not read as octal" {
	at 00 00 00
	[ "$(foundation_day_start 0)" -eq 1000000 ]
	at 09 08 07
	[ "$(foundation_day_start 09)" -eq $((1000000 - (8 * 60 + 7))) ]
}
