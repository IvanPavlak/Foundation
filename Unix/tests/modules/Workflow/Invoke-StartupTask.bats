#!/usr/bin/env bats
# Invoke-StartupTask against a test startup.conf and log folder, with harmless commands that write
# under the test folder: a configured task by name and an ad-hoc --command, the flags winning over
# the task's lines, the gates (Disabled, OutOfScope, NotDue) and --force, the stamp written only
# after a success, the conditions (met, not met, --no-condition-wait), the lock, --elevation prompt
# against a stand-in sudo, --dry-run, a hidden window run end to end (also one whose shell dies:
# Ended) and a tab against the WezTerm stand-in of tests/platform.bash (never a real WezTerm).

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	use_empty_config
	export FOUNDATION_LOG_DIR=$BATS_TEST_TMPDIR/logs STARTUP_POLL=0.1
	logs=$FOUNDATION_LOG_DIR
	out=$BATS_TEST_TMPDIR/out
	cmd=$UNIX_DIR/modules/Workflow/bin/Invoke-StartupTask
	. "$UNIX_DIR/lib/daystart.sh"
}

conf() { printf '%s\n' "$@" >"$FOUNDATION_CONFIG_DIR/startup.conf"; }
stamp() { printf '%s' "$logs/.startup-task-$1.stamp"; }
# Lines the task commands wrote.
written() { cat "$out" 2>/dev/null || true; }

# Sets FILE's modification time to an epoch second (GNU date -d, BSD date -r). Usage: touch_at EPOCH FILE
touch_at() {
	touch -t "$(date -d "@$1" +%Y%m%d%H%M.%S 2>/dev/null || date -r "$1" +%Y%m%d%H%M.%S)" "$2"
}

@test "a configured task runs by name in this shell: its command, the stamp, the lock released" {
	conf "[Hello]" "command echo \"hello \$FOUNDATION_STARTUP_TASK\" >>$out" "trigger SignIn"
	run "${BASH:-bash}" "$cmd" hello
	[ "$status" -eq 0 ]
	[[ $output == *Succeeded* ]]
	[ "$(written)" = "hello Hello" ]
	[ -e "$(stamp Hello)" ]
	[ ! -e "$logs/.startup-task-Hello.lock" ]
}

@test "an ad-hoc --command needs no startup.conf" {
	run "${BASH:-bash}" "$cmd" Adhoc --command "echo adhoc >>$out"
	[ "$status" -eq 0 ]
	[ "$(written)" = adhoc ]
	[ -e "$(stamp Adhoc)" ]
}

@test "a failing command is Failed: exit 1, no stamp, the lock released" {
	run "${BASH:-bash}" "$cmd" Broken --command 'exit 3'
	[ "$status" -eq 1 ]
	[[ $output == *Failed* ]]
	[[ $output == *3* ]]
	[ ! -e "$(stamp Broken)" ]
	[ ! -e "$logs/.startup-task-Broken.lock" ]
}

@test "a name startup.conf does not know, a task that is not valid and a bad name fail and run nothing" {
	conf "[Invalid]" "command echo ran >>$out" "trigger SignIn" "colour blue"
	run "${BASH:-bash}" "$cmd" Missing
	[ "$status" -eq 1 ]
	run "${BASH:-bash}" "$cmd" Invalid
	[ "$status" -eq 1 ]
	[[ $output == *"[colour]"* ]]
	run "${BASH:-bash}" "$cmd" 'Bad.Name' --command "echo ran >>$out"
	[ "$status" -ne 0 ]
	[ -z "$(written)" ]
}

@test "a section whose every line is for another machine type is no task on this one" {
	conf "[Other]" "@Laptop command echo ran >>$out" "@Laptop trigger SignIn"
	CONF_MACHINE_TYPE=Work run "${BASH:-bash}" "$cmd" Other
	[ "$status" -eq 1 ]
	[[ $output == *"No startup task named"* ]]
	[ -z "$(written)" ]
	CONF_MACHINE_TYPE=Laptop run "${BASH:-bash}" "$cmd" Other
	[ "$status" -eq 0 ]
	[ "$(written)" = ran ]
}

@test "argument errors: an unknown flag, a value missing, an unknown window, frequency or trigger, two names" {
	for args in "Task --nope" "Task --command" "Task --window floating" "Task --frequency weekly" \
		"Task --trigger Wake" "One Two" "--command true" "Task --elevation relaunch" "Task --day-start-hour 24"; do
		# shellcheck disable=SC2086 # the words of each case are its arguments
		run "${BASH:-bash}" "$cmd" $args
		[ "$status" -ne 0 ] || {
			echo "[$args] was accepted"
			return 1
		}
	done
}

@test "Disabled: a parked task (enabled off, --disabled) does not run; --force runs it" {
	conf "[Parked]" "command echo parked >>$out" "trigger SignIn" "enabled off"
	run "${BASH:-bash}" "$cmd" Parked
	[ "$status" -eq 0 ]
	[[ $output == *Disabled* ]]
	run "${BASH:-bash}" "$cmd" Adhoc --command "echo adhoc >>$out" --disabled
	[[ $output == *Disabled* ]]
	[ -z "$(written)" ]
	run "${BASH:-bash}" "$cmd" Parked --force
	[ "$status" -eq 0 ]
	[ "$(written)" = parked ]
}

@test "OutOfScope: another machine type or host does not run, not even with --force" {
	conf "[Laptop]" "command echo ran >>$out" "trigger SignIn" "machine Laptop"
	CONF_MACHINE_TYPE=Work run "${BASH:-bash}" "$cmd" Laptop
	[ "$status" -eq 0 ]
	[[ $output == *OutOfScope* ]]
	CONF_MACHINE_TYPE=Work run "${BASH:-bash}" "$cmd" Laptop --force
	[[ $output == *OutOfScope* ]]
	CONF_MACHINE_TYPE=Work run "${BASH:-bash}" "$cmd" Adhoc --command "echo ran >>$out" --host No-Such-Host --force
	[[ $output == *OutOfScope* ]]
	[ -z "$(written)" ]
	# --machine on the command line wins over the task's line.
	CONF_MACHINE_TYPE=Work run "${BASH:-bash}" "$cmd" Laptop --machine Work
	[ "$(written)" = ran ]
	CONF_MACHINE_TYPE=Laptop run "${BASH:-bash}" "$cmd" Laptop
	[ "$(written | wc -l | tr -d ' ')" -eq 2 ]
}

@test "NotDue: once-per-day after a run today; --force and a --frequency flag run it anyway" {
	conf "[Daily]" "command echo ran >>$out" "trigger SignIn" "frequency once-per-day"
	run "${BASH:-bash}" "$cmd" Daily
	[ "$(written)" = ran ]
	run "${BASH:-bash}" "$cmd" Daily
	[ "$status" -eq 0 ]
	[[ $output == *NotDue* ]]
	[ "$(written | wc -l | tr -d ' ')" -eq 1 ]
	run "${BASH:-bash}" "$cmd" Daily --force
	[ "$(written | wc -l | tr -d ' ')" -eq 2 ]
	run "${BASH:-bash}" "$cmd" Daily --frequency every-time
	[ "$(written | wc -l | tr -d ' ')" -eq 3 ]
}

@test "once-per-day: a stamp from before the day started is due; --day-start-hour moves the boundary" {
	conf "[Daily]" "command echo ran >>$out" "trigger SignIn" "frequency once-per-day"
	mkdir -p "$logs" && date >"$(stamp Daily)"
	touch_at $(($(foundation_day_start 6) - 60)) "$(stamp Daily)"
	run "${BASH:-bash}" "$cmd" Daily
	[ "$(written)" = ran ]
	touch_at $(($(foundation_day_start 14) - 60)) "$(stamp Daily)"
	run "${BASH:-bash}" "$cmd" Daily --day-start-hour 14
	[ "$(written | wc -l | tr -d ' ')" -eq 2 ]
}

@test "interval and once-per-boot: the stamp's age and the boot time decide" {
	mkdir -p "$logs"
	now=$(date +%s)
	date >"$(stamp Interval)" && touch_at $((now - 7200)) "$(stamp Interval)"
	run "${BASH:-bash}" "$cmd" Interval --command "echo interval >>$out" --frequency interval --interval-hours 3
	[[ $output == *NotDue* ]]
	run "${BASH:-bash}" "$cmd" Interval --command "echo interval >>$out" --frequency interval --interval-hours 1
	[ "$(written)" = interval ]
	date >"$(stamp Boot)" && touch_at $((now - 600)) "$(stamp Boot)"
	FOUNDATION_BOOT_TIME=$((now - 900)) run "${BASH:-bash}" "$cmd" Boot --command "echo boot >>$out" --frequency once-per-boot
	[[ $output == *NotDue* ]]
	FOUNDATION_BOOT_TIME=$((now - 300)) run "${BASH:-bash}" "$cmd" Boot --command "echo boot >>$out" --frequency once-per-boot
	[ "$(written | tail -n 1)" = boot ]
}

@test "the stamp is written only after a success: a failed once-per-day task is due again" {
	run "${BASH:-bash}" "$cmd" Flaky --command "echo try >>$out; exit 1" --frequency once-per-day
	[ "$status" -eq 1 ]
	[ ! -e "$(stamp Flaky)" ]
	run "${BASH:-bash}" "$cmd" Flaky --command "echo try >>$out; exit 1" --frequency once-per-day
	[ "$(written | wc -l | tr -d ' ')" -eq 2 ]
}

@test "conditions: a met one runs the task, one not met skips it with no stamp, --no-condition-wait tests once" {
	conf "condition Up 1 0.1 true" "condition Down 1 0.1 false" "condition Never 60 0.1 false"
	run "${BASH:-bash}" "$cmd" Task --command "echo ran >>$out" --requires Up
	[ "$status" -eq 0 ]
	[ "$(written)" = ran ]
	run "${BASH:-bash}" "$cmd" Task --command "echo ran >>$out" --requires Up,Down
	[ "$status" -eq 1 ]
	[[ $output == *Skipped* ]]
	[[ $output == *"[Down]"* ]]
	# Tested once: a condition that would be waited for a minute skips at once.
	start=$SECONDS
	run "${BASH:-bash}" "$cmd" Skip --command "echo ran >>$out" --requires Never --no-condition-wait
	[ "$status" -eq 1 ]
	[[ $output == *Skipped* ]]
	[ $((SECONDS - start)) -lt 30 ]
	[ "$(written | wc -l | tr -d ' ')" -eq 1 ]
	[ ! -e "$(stamp Skip)" ]
}

@test "a condition startup.conf does not name is an error before anything runs" {
	conf "condition Up 0 true"
	run "${BASH:-bash}" "$cmd" Task --command "echo ran >>$out" --requires Nope
	[ "$status" -ne 0 ]
	[ -z "$(written)" ]
}

@test "the lock: a live owner makes the run AlreadyRunning, a dead owner's lock is taken over" {
	mkdir -p "$logs/.startup-task-Locked.lock"
	echo $$ >"$logs/.startup-task-Locked.lock/pid"
	run "${BASH:-bash}" "$cmd" Locked --command "echo ran >>$out"
	[ "$status" -eq 0 ]
	[[ $output == *AlreadyRunning* ]]
	[ -z "$(written)" ]
	[ ! -e "$(stamp Locked)" ]
	echo 99999999 >"$logs/.startup-task-Locked.lock/pid"
	run "${BASH:-bash}" "$cmd" Locked --command "echo ran >>$out"
	[ "$status" -eq 0 ]
	[ "$(written)" = ran ]
	[ ! -e "$logs/.startup-task-Locked.lock" ]
}

@test "--elevation prompt asks sudo once before the command; a refusal fails the task and runs nothing" {
	stub_tool sudo 'case "$1" in -v) [ -z "$SUDO_REFUSE" ] || exit 1 ;; esac; exit 0'
	[ "$(command -v sudo)" = "$BATS_TEST_TMPDIR/tools/sudo" ]
	SUDO_REFUSE=1 run "${BASH:-bash}" "$cmd" Admin --command "echo ran >>$out" --elevation prompt
	[ "$status" -eq 1 ]
	[ -z "$(written)" ]
	run "${BASH:-bash}" "$cmd" Admin --command "echo ran >>$out" --elevation prompt
	[ "$status" -eq 0 ]
	[ "$(written)" = ran ]
	[ "$(grep -c '^sudo -v' "$BATS_TEST_TMPDIR/tool.log")" -eq 2 ]
	# sudo cannot ask in a hidden window.
	run "${BASH:-bash}" "$cmd" Admin --command "echo ran >>$out" --elevation prompt --window hidden
	[ "$status" -ne 0 ]
	[ "$(written | wc -l | tr -d ' ')" -eq 1 ]
}

@test "--dry-run runs nothing: WouldRun, with the conditions it would wait for, or why not" {
	conf "condition Down 0 false" "[Daily]" "command echo ran >>$out" "trigger SignIn" "frequency once-per-day"
	run "${BASH:-bash}" "$cmd" Task --command "echo ran >>$out" --requires Down --dry-run
	[ "$status" -eq 0 ]
	[[ $output == *WouldRun* ]]
	[[ $output == *Down* ]]
	mkdir -p "$logs" && date >"$(stamp Daily)"
	run "${BASH:-bash}" "$cmd" Daily --dry-run
	[[ $output == *NotDue* ]]
	[ -z "$(written)" ]
	[ ! -e "$(stamp Task)" ]
}

@test "a result file gets the final record" {
	run "${BASH:-bash}" "$cmd" Task --command 'exit 2' --result-file "$BATS_TEST_TMPDIR/result"
	[ "$status" -eq 1 ]
	IFS=$'\t' read -r status_field pid _ <"$BATS_TEST_TMPDIR/result"
	[ "$status_field" = Failed ]
	[ -n "$pid" ]
}

# bats test_tags=integration
@test "hidden: the task runs in a background process; the starter waits for its result and gets the stamp" {
	run "${BASH:-bash}" "$cmd" Hidden --command "echo \"\$FOUNDATION_STARTUP_TASK_SHELL\" >>$out" --window hidden --timeout 30
	[ "$status" -eq 0 ]
	[[ $output == *Succeeded* ]]
	[ "$(written)" = 1 ]
	[ -e "$(stamp Hidden)" ]
	[ "$(cut -f1 "$logs/.startup-task-Hidden.result")" = Succeeded ]
	run "${BASH:-bash}" "$cmd" HiddenFail --command 'exit 4' --window hidden --timeout 30
	[ "$status" -eq 1 ]
	[[ $output == *Failed* ]]
	[ ! -e "$(stamp HiddenFail)" ]
}

# bats test_tags=integration
@test "hidden: a task whose shell dies before it reports is Ended, and its stamp is written" {
	# The command ends the task's own runner (its parent), so no final record is written.
	run "${BASH:-bash}" "$cmd" Dies --command 'kill -9 $PPID' --window hidden --timeout 30
	[ "$status" -eq 0 ]
	[[ $output == *Ended* ]]
	[ -e "$(stamp Dies)" ]
}

@test "tab: a WezTerm tab in a new FoundationStartup window, its shell marked and closed on success; --parallel returns Started" {
	platform_stubs
	run "${BASH:-bash}" "$cmd" Tabbed --command "echo ran >>$out" --window tab --parallel
	[ "$status" -eq 0 ]
	[[ $output == *Started* ]]
	grep -q 'spawn --new-window' "$STUB_LOG"
	grep -q 'FOUNDATION_SKIP_STARTUP_PANEL=1' "$STUB_LOG"
	grep -q 'export FOUNDATION_STARTUP_TASK_SHELL=1;' "$STUB_LOG"
	grep -q -- '--window current' "$STUB_LOG"
	grep -q -- "--result-file $logs/.startup-task-Tabbed.result" "$STUB_LOG"
	grep -q '&& exit' "$STUB_LOG"
	# The stand-in runs nothing: no task ran here.
	[ -z "$(written)" ]
}

@test "tab: keep-open never always closes, always keeps it; a task without a command is a plain terminal" {
	platform_stubs
	run "${BASH:-bash}" "$cmd" Never --command "echo ran >>$out" --window tab --parallel --keep-open never
	grep -q '; exit' "$STUB_LOG"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Always --command "echo ran >>$out" --window tab --parallel --keep-open always
	grep -q 'send-text' "$STUB_LOG"
	! grep -q 'exit$' "$STUB_LOG" || false
	: >"$STUB_LOG"
	conf "[Plain]" "trigger SignIn"
	run "${BASH:-bash}" "$cmd" Plain --window tab --parallel
	[ "$status" -eq 0 ]
	! grep -q 'FOUNDATION_STARTUP_TASK_SHELL' "$STUB_LOG" || false
	! grep -q 'FOUNDATION_SKIP_STARTUP_PANEL' "$STUB_LOG" || false
}

@test "tab: without --parallel the starter waits up to --timeout, then the task is TimedOut and left running" {
	platform_stubs
	run "${BASH:-bash}" "$cmd" Slow --command "echo ran >>$out" --window tab --timeout 1
	[ "$status" -eq 1 ]
	[[ $output == *TimedOut* ]]
	[ ! -e "$(stamp Slow)" ]
}

@test "tab: a WezTerm that opens no tab fails the task" {
	platform_stubs
	# A stand-in whose spawn prints no pane id.
	printf '#!/bin/sh\necho "wezterm $*" >>"$STUB_LOG"\ncase "$*" in *" list "*) cat "$STUB_PANES" ;; esac\nexit 0\n' >"$STUB_BIN/wezterm"
	run "${BASH:-bash}" "$cmd" NoTab --command "echo ran >>$out" --window tab --parallel
	[ "$status" -eq 1 ]
	[[ $output == *Failed* ]]
}
