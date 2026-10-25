#!/usr/bin/env bats
# Invoke-StartupRepositoryUpdate against throwaway repositories and a test log folder: off unless
# configured, once a day or once per interval (stamp), the recorded next due time, one run across
# shells (lock, stale lock cleared), the configured scope (groups only; without one Bootstrap's
# repository-scope, then All), never cloning, --force.

# bats file_tags=integration
load ../../helpers
load ../../git

setup() {
	setup_foundation
	git_sandbox
	export FOUNDATION_CONFIG_DIR=$BATS_TEST_TMPDIR/config FOUNDATION_LOG_DIR=$BATS_TEST_TMPDIR/logs
	mkdir -p "$FOUNDATION_CONFIG_DIR"
	stamp=$FOUNDATION_LOG_DIR/.last-repository-update
	lock=$FOUNDATION_LOG_DIR/.repository-update.lock
	next_file=$FOUNDATION_LOG_DIR/.next-repository-update
	cmd=$bin/Invoke-StartupRepositoryUpdate
	. "$UNIX_DIR/lib/daystart.sh"
}

# Sets FILE's modification time to an epoch second (GNU date -d, BSD date -r). Usage: touch_at EPOCH FILE
touch_at() {
	touch -t "$(date -d "@$1" +%Y%m%d%H%M.%S 2>/dev/null || date -r "$1" +%Y%m%d%H%M.%S)" "$2"
}

conf() {
	{
		printf '%s\n' "$@"
		printf '[Mine]\nRepo  %s  %s\n[Theirs]\nMissing  %s  %s/missing\n' "$(origin_url Repo)" "$REPO" "$(origin_url Missing)" "$BATS_TEST_TMPDIR"
	} >"$FOUNDATION_CONFIG_DIR/repositories.conf"
}

@test "off by default: nothing runs, no stamp" {
	conf ""
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	[ ! -e "$stamp" ]
}

@test "enabled: updates every group without cloning, writes the stamp, releases the lock" {
	conf "startup on"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"[Repo] master - up to date"* ]]
	[[ $output == *"[Missing] not cloned on this machine - skipped"* ]]
	[ -e "$stamp" ]
	[ ! -e "$lock" ]
	[ ! -e "$BATS_TEST_TMPDIR/missing" ]
}

@test "a fresh stamp skips the run, --force runs anyway, even when disabled" {
	conf "startup on"
	mkdir -p "$FOUNDATION_LOG_DIR" && date >"$stamp"
	run "${BASH:-bash}" "$cmd"
	[ -z "$output" ]
	conf ""
	run "${BASH:-bash}" "$cmd" --force
	[[ $output == *"[Repo]"* ]]
}

@test "an old stamp runs again" {
	conf "startup on"
	mkdir -p "$FOUNDATION_LOG_DIR" && date >"$stamp" && touch -t 200001010000 "$stamp"
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"[Repo]"* ]]
}

@test "daily (the default): a run before the day started runs again, one since then skips" {
	conf "startup on"
	start=$(foundation_day_start 6)
	mkdir -p "$FOUNDATION_LOG_DIR" && date >"$stamp"
	touch_at $((start - 60)) "$stamp"
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"[Repo]"* ]]
	touch_at $((start + 60)) "$stamp"
	run "${BASH:-bash}" "$cmd"
	[ -z "$output" ]
}

@test "startup-day-start-hour moves the day boundary" {
	conf "startup on" "startup-day-start-hour 14"
	mkdir -p "$FOUNDATION_LOG_DIR" && date >"$stamp"
	touch_at $(($(foundation_day_start 14) - 60)) "$stamp"
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"[Repo]"* ]]
}

@test "interval: the stamp's age decides, not the day boundary" {
	conf "startup on" "startup-schedule interval" "startup-interval-hours 48"
	mkdir -p "$FOUNDATION_LOG_DIR" && date >"$stamp"
	touch_at $(($(foundation_day_start 6) - 60)) "$stamp"
	run "${BASH:-bash}" "$cmd"
	[ -z "$output" ]
	conf "startup on" "startup-schedule interval" "startup-interval-hours 1"
	touch -t 200001010000 "$stamp"
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"[Repo]"* ]]
}

@test "records when the next run is due, for the shell rc's prompt hook" {
	conf "startup on"
	run "${BASH:-bash}" "$cmd"
	read -r next schedule <"$next_file"
	[ "$next" -eq $(($(foundation_day_start 6) + 86400)) ]
	[ "$schedule" = daily ]
	conf "startup on" "startup-schedule interval" "startup-interval-hours 2"
	run "${BASH:-bash}" "$cmd"
	read -r next schedule <"$next_file"
	[ "$next" -gt "$(date +%s)" ]
	[ "$schedule" = interval ]
}

@test "a lock held by a live shell skips the run, a lock left by a dead one is cleared" {
	conf "startup on"
	mkdir -p "$lock" && echo $$ >"$lock/pid"
	run "${BASH:-bash}" "$cmd"
	[ -z "$output" ]
	[ ! -e "$stamp" ]
	echo 99999999 >"$lock/pid"
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"[Repo]"* ]]
	[ ! -e "$lock" ]
}

@test "startup-scope picks the groups, per machine type" {
	# No machines.conf in the test config: the machine type is MACHINE_TYPE.
	conf "startup on" "startup-scope Theirs" "@Work startup-scope Mine"
	MACHINE_TYPE=Laptop run "${BASH:-bash}" "$cmd"
	[[ $output == *"[Missing]"* ]]
	[[ $output != *"[Repo]"* ]]
	rm -f "$stamp"
	MACHINE_TYPE=Work run "${BASH:-bash}" "$cmd"
	[[ $output == *"[Repo]"* ]]
	[[ $output != *"[Missing]"* ]]
}

@test "without a startup-scope the repository-scope of bootstrap.conf applies, then All" {
	# No machines.conf in the test config: the machine type is MACHINE_TYPE.
	conf "startup on"
	MACHINE_TYPE=Laptop run "${BASH:-bash}" "$cmd"
	[[ $output == *"[Repo]"* ]]
	[[ $output == *"[Missing]"* ]]
	rm -f "$stamp"
	printf 'repository-scope All\n@Work repository-scope Mine\n' >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	MACHINE_TYPE=Work run "${BASH:-bash}" "$cmd"
	[[ $output == *"[Repo]"* ]]
	[[ $output != *"[Missing]"* ]]
	rm -f "$stamp"
	MACHINE_TYPE=Laptop run "${BASH:-bash}" "$cmd"
	[[ $output == *"[Missing]"* ]]
	# A startup-scope line wins over the Bootstrap one.
	rm -f "$stamp"
	conf "startup on" "startup-scope Theirs"
	MACHINE_TYPE=Work run "${BASH:-bash}" "$cmd"
	[[ $output == *"[Missing]"* ]]
	[[ $output != *"[Repo]"* ]]
	# The fallback names groups only too.
	rm -f "$stamp"
	conf "startup on"
	printf 'repository-scope Repo\n' >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"Unknown repository group [Repo] in the repository-scope of bootstrap.conf"* ]]
	[[ $output != *"[Missing]"* ]]
}

@test "startup-scope names groups only, as on Windows: a repository name or a typo updates nothing" {
	conf "startup on" "startup-scope Mine Repo"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Unknown repository group [Repo]"* ]]
	[[ $output != *"[Repo] master"* ]]
	[[ $output != *"[Missing]"* ]]
	rm -f "$stamp"
	conf "startup on" "startup-scope mine"
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"[Repo] master - up to date"* ]]
}

@test "an unknown argument is an error" {
	run "${BASH:-bash}" "$cmd" --bogus
	[ "$status" -ne 0 ]
}

# FILE's modification time in epoch seconds (GNU stat -c, BSD stat -f). Usage: mtime FILE
mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"; }

@test "an unknown startup-schedule behaves as daily" {
	conf "startup on" "startup-schedule weekly"
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"[Repo]"* ]]
	read -r next schedule <"$next_file"
	[ "$schedule" = daily ]
	[ "$next" -eq $(($(foundation_day_start 6) + 86400)) ]
	run "${BASH:-bash}" "$cmd"
	[ -z "$output" ]
}

@test "a startup-day-start-hour that is no hour from 0 to 23 is 6" {
	for hour in 25 abc; do
		rm -f "$stamp"
		conf "startup on" "startup-day-start-hour $hour"
		run "${BASH:-bash}" "$cmd"
		[[ $output == *"[Repo]"* ]]
		read -r next schedule <"$next_file"
		[ "$next" -eq $(($(foundation_day_start 6) + 86400)) ] || {
			echo "startup-day-start-hour $hour: next run at $next"
			return 1
		}
	done
}

@test "a fractional startup-interval-hours is 24" {
	conf "startup on" "startup-schedule interval" "startup-interval-hours 1.5"
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"[Repo]"* ]]
	read -r next schedule <"$next_file"
	[ "$schedule" = interval ]
	[ "$next" -eq $(($(mtime "$stamp") + 86400)) ]
}

@test "startup-interval-hours 0 runs every time" {
	conf "startup on" "startup-schedule interval" "startup-interval-hours 0"
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"[Repo]"* ]]
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"[Repo]"* ]]
}

@test "an update that fails still releases the lock and keeps the stamp" {
	conf "startup on"
	mv "$ORIGIN" "$ORIGIN.gone"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"[Repo] master - could not fetch from origin"* ]]
	[ ! -e "$lock" ]
	[ -e "$stamp" ]
}

@test "a lock held by a live shell wins over --force" {
	conf "startup on"
	mkdir -p "$lock" && echo $$ >"$lock/pid"
	run "${BASH:-bash}" "$cmd" --force
	[ -z "$output" ]
	[ ! -e "$stamp" ]
	[ "$(cat "$lock/pid")" = $$ ]
}

@test "a fresh stamp takes no lock: a stale one is not even cleared" {
	conf "startup on"
	mkdir -p "$FOUNDATION_LOG_DIR" && date >"$stamp"
	mkdir -p "$lock" && echo 99999999 >"$lock/pid"
	run "${BASH:-bash}" "$cmd"
	[ -z "$output" ]
	[ "$(cat "$lock/pid")" = 99999999 ]
}
