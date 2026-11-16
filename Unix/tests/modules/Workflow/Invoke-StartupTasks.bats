#!/usr/bin/env bats
# Invoke-StartupTasks against a test startup.conf and log folder, with harmless commands that write
# under the test folder: the trigger argument, the terminal-open run (inline, in file order, a
# failing task not stopping the next, a condition not met skipped silently, nothing in a task's
# own shell), --name, --dry-run, the gate it records for the shell rc, the sign-in run (hidden
# tasks one after the other, a parallel one collected at the end, a tab task timing out) and the
# failure report, against the WezTerm stand-in of tests/platform.bash (never a real WezTerm).

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	use_empty_config
	export FOUNDATION_LOG_DIR=$BATS_TEST_TMPDIR/logs STARTUP_POLL=0.1 CONF_MACHINE_TYPE=Work
	logs=$FOUNDATION_LOG_DIR
	out=$BATS_TEST_TMPDIR/out
	gate=$logs/.startup-terminal-open
	cmd=$UNIX_DIR/modules/Workflow/bin/Invoke-StartupTasks
	. "$UNIX_DIR/lib/daystart.sh"
}

conf() { printf '%s\n' "$@" >"$FOUNDATION_CONFIG_DIR/startup.conf"; }
stamp() { printf '%s' "$logs/.startup-task-$1.stamp"; }
# The lines the task commands wrote, joined by spaces.
written() { if [ -f "$out" ]; then paste -sd' ' - <"$out"; fi; }

@test "the trigger is required; Unlock, Wake and unknown triggers are errors; nothing runs" {
	conf "[Task]" "command echo ran >>$out" "trigger SignIn TerminalOpen"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	for trigger in Unlock wake Boot Manual Sometimes; do
		run "${BASH:-bash}" "$cmd" --trigger "$trigger"
		[ "$status" -ne 0 ] || {
			echo "--trigger $trigger was accepted"
			return 1
		}
	done
	run "${BASH:-bash}" "$cmd" --trigger TerminalOpen --nope
	[ "$status" -ne 0 ]
	[ -z "$(written)" ]
}

@test "terminal open: the tasks of the trigger run inline in file order; a failing one does not stop the next" {
	conf "[First]" "command echo first >>$out" "trigger TerminalOpen" "window hidden" \
		"[SignInOnly]" "command echo signin >>$out" "trigger SignIn" \
		"[Fails]" "command echo fails >>$out; exit 1" "trigger TerminalOpen" \
		"[Last]" "command echo last >>$out" "trigger SignIn TerminalOpen"
	run "${BASH:-bash}" "$cmd" --trigger terminal-open
	[ "$status" -eq 0 ]
	[ "$(written)" = "first fails last" ]
	[ -e "$(stamp First)" ]
	[ ! -e "$(stamp Fails)" ]
	[ -e "$(stamp Last)" ]
	[ ! -e "$(stamp SignInOnly)" ]
}

@test "terminal open: a condition not met is tested once and skipped silently, and the gate backs off" {
	conf "condition Never 60 0.1 false" \
		"[Offline]" "command echo offline >>$out" "trigger TerminalOpen" "requires Never"
	before=$(date +%s)
	start=$SECONDS
	run "${BASH:-bash}" "$cmd" --trigger TerminalOpen
	[ "$status" -eq 0 ]
	[ $((SECONDS - start)) -lt 30 ]
	[[ $output != *Offline* ]]
	[ -z "$(written)" ]
	[ ! -e "$(stamp Offline)" ]
	read -r next _ <"$gate"
	[ "$next" -ge $((before + 300)) ]
}

@test "terminal open: nothing runs in a shell a startup task runs in, and no gate is written" {
	conf "[Task]" "command echo ran >>$out" "trigger TerminalOpen"
	FOUNDATION_STARTUP_TASK_SHELL=1 run "${BASH:-bash}" "$cmd" --trigger TerminalOpen
	[ "$status" -eq 0 ]
	[ -z "$(written)" ]
	[ ! -e "$gate" ]
}

@test "terminal open: a task that is not valid is reported, never run, and keeps the gate due" {
	conf "[Broken]" "command echo broken >>$out" "trigger TerminalOpen" "colour blue" \
		"[Fine]" "command echo fine >>$out" "trigger TerminalOpen" "frequency once-per-day"
	run "${BASH:-bash}" "$cmd" --trigger TerminalOpen
	[ "$status" -eq 0 ]
	[[ $output == *Broken* ]]
	[ "$(written)" = fine ]
	[ "$(head -n 1 "$gate" | cut -d' ' -f1)" = 0 ]
}

@test "the gate: none without a terminal-open task; a once-per-day task records its boundary and stamp" {
	conf "[SignInOnly]" "command true" "trigger SignIn" "window hidden"
	run "${BASH:-bash}" "$cmd" --trigger TerminalOpen
	[ "$(cat "$gate")" = "none 0" ]
	conf "[Daily]" "command echo daily >>$out" "trigger TerminalOpen" "frequency once-per-day"
	run "${BASH:-bash}" "$cmd" --trigger TerminalOpen
	boundary=$(($(foundation_day_start 6) + 86400))
	[ "$(head -n 1 "$gate")" = "$boundary $boundary" ]
	[ "$(tail -n +2 "$gate")" = "$(stamp Daily)" ]
	# The next run is not due: the task does not run twice in a day.
	run "${BASH:-bash}" "$cmd" --trigger TerminalOpen
	[ "$(written)" = daily ]
}

@test "--name runs only the named tasks, in any case, comma-separated or repeated" {
	conf "[One]" "command echo one >>$out" "trigger TerminalOpen" \
		"[Two]" "command echo two >>$out" "trigger TerminalOpen" \
		"[Three]" "command echo three >>$out" "trigger TerminalOpen"
	run "${BASH:-bash}" "$cmd" --trigger TerminalOpen --name three
	[ "$(written)" = three ]
	: >"$out"
	run "${BASH:-bash}" "$cmd" --trigger TerminalOpen --name 'Three, one'
	[ "$(written)" = "one three" ]
	: >"$out"
	run "${BASH:-bash}" "$cmd" --trigger TerminalOpen --name two --name One
	[ "$(written)" = "one two" ]
}

@test "--dry-run lists WouldRun, NotDue, OutOfScope, Disabled and Failed per task and runs nothing" {
	conf "condition Down 0 false" \
		"[Would]" "command echo would >>$out" "trigger SignIn" "requires Down" "window hidden" \
		"[Done]" "command echo done >>$out" "trigger SignIn" "frequency once-per-day" \
		"[Elsewhere]" "command echo elsewhere >>$out" "trigger SignIn" "machine Laptop" \
		"[Parked]" "command echo parked >>$out" "trigger SignIn" "enabled off" \
		"[Broken]" "command echo broken >>$out" "trigger SignIn" "colour blue" \
		"[TerminalOnly]" "command echo terminal >>$out" "trigger TerminalOpen"
	mkdir -p "$logs" && date >"$(stamp Done)"
	run "${BASH:-bash}" "$cmd" --trigger SignIn --dry-run
	[ "$status" -eq 0 ]
	[[ $output =~ Would\ +WouldRun\ +Would\ wait\ for:\ Down ]]
	[[ $output =~ Done\ +NotDue ]]
	[[ $output =~ Elsewhere\ +OutOfScope ]]
	[[ $output =~ Parked\ +Disabled ]]
	[[ $output =~ Broken\ +Failed\ +Not\ valid ]]
	[[ $output != *TerminalOnly* ]]
	[ -z "$(written)" ]
	[ ! -e "$gate" ]
	[ ! -e "$logs/.startup-report-SignIn.txt" ]
	conf "[TerminalOnly]" "command true" "trigger TerminalOpen"
	run "${BASH:-bash}" "$cmd" --trigger SignIn --dry-run
	[ "$status" -eq 0 ]
	[[ $output == *"No startup task has the trigger SignIn"* ]]
}

# bats test_tags=integration
@test "sign-in: hidden tasks run one after the other, each waited for; every result gets a line" {
	conf "failure-report none" \
		"[Slow]" "command sleep 0.5; echo slow >>$out" "trigger SignIn" "window hidden" \
		"[Fast]" "command echo fast >>$out" "trigger SignIn" "window hidden"
	run "${BASH:-bash}" "$cmd" --trigger SignIn
	[ "$status" -eq 0 ]
	[ "$(written)" = "slow fast" ]
	[ -e "$(stamp Slow)" ]
	[ -e "$(stamp Fast)" ]
	[[ $output == *"[Slow] finished"* ]]
	[[ $output == *"[Fast] finished"* ]]
}

# bats test_tags=integration
@test "sign-in: a parallel task is started, the next runs at once, and it is collected before the run ends" {
	conf "failure-report none" \
		"[Background]" "command sleep 1; echo background >>$out" "trigger SignIn" "window hidden" "parallel on" \
		"[Next]" "command echo next >>$out" "trigger SignIn" "window hidden"
	run "${BASH:-bash}" "$cmd" --trigger SignIn
	[ "$status" -eq 0 ]
	[ "$(written)" = "next background" ]
	[ -e "$(stamp Background)" ]
	[[ $output == *"[Background] finished"* ]]
}

@test "sign-in: a tab task that reports nothing times out; failure-report none opens no report" {
	platform_stubs
	conf "failure-report None" "[Tabbed]" "command echo ran >>$out" "trigger SignIn" "timeout 1"
	run "${BASH:-bash}" "$cmd" --trigger SignIn
	[ "$status" -eq 0 ]
	[[ $output == *"[Tabbed] timed out"* ]]
	[ ! -e "$logs/.startup-report-SignIn.txt" ]
	# The one spawn is the task's own tab.
	[ "$(grep -c spawn "$STUB_LOG")" -eq 1 ]
}

@test "sign-in: a task that did not finish is listed in a report tab (failure-report tab, the default)" {
	platform_stubs
	conf "[Broken]" "command echo broken >>$out" "trigger SignIn" "colour blue" \
		"[Parked]" "command true" "trigger SignIn" "enabled off"
	run "${BASH:-bash}" "$cmd" --trigger SignIn
	[ "$status" -eq 0 ]
	report=$logs/.startup-report-SignIn.txt
	[ -f "$report" ]
	grep -q '\[Broken\] Failed' "$report"
	! grep -q Parked "$report" || false
	grep -q 'spawn' "$STUB_LOG"
	grep -qF "cat $report" "$STUB_LOG"
	[ -z "$(written)" ]
}

@test "sign-in: a run in which every task finished opens no report" {
	platform_stubs
	conf "[Parked]" "command true" "trigger SignIn" "enabled off"
	run "${BASH:-bash}" "$cmd" --trigger SignIn
	[ "$status" -eq 0 ]
	[ ! -e "$logs/.startup-report-SignIn.txt" ]
	! grep -q spawn "$STUB_LOG" || false
}
