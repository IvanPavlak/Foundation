#!/usr/bin/env bats
# Unix/lib/startup.sh, the shared logic of the startup tasks: value spellings, the settings and
# conditions before the first section, loading a task (defaults, every validation rule, a section
# for other machine types, the machine and host scope), the frequency (every-time, once-per-boot
# against FOUNDATION_BOOT_TIME, once-per-day, interval), the lock (live, dead and ownerless
# owners), the result file and the wait for it (final record, Ended, TimedOut), the terminal-open
# gate and the LaunchAgent property list. Every state file goes to a test log folder.

load helpers

setup() {
	setup_foundation
	use_empty_config
	export FOUNDATION_LOG_DIR=$BATS_TEST_TMPDIR/logs STARTUP_POLL=0.1
	foundation_load daystart startup
	logs=$FOUNDATION_LOG_DIR
	mkdir -p "$logs"
}

conf() { printf '%s\n' "$@" >"$FOUNDATION_CONFIG_DIR/startup.conf"; }

# Sets FILE's modification time to an epoch second (GNU date -d, BSD date -r). Usage: touch_at EPOCH FILE
touch_at() {
	touch -t "$(date -d "@$1" +%Y%m%d%H%M.%S 2>/dev/null || date -r "$1" +%Y%m%d%H%M.%S)" "$2"
}

# A stamp file of task NAME written at EPOCH. Usage: stamp_at NAME EPOCH
stamp_at() {
	date >"$logs/.startup-task-$1.stamp"
	touch_at "$2" "$logs/.startup-task-$1.stamp"
}

# The ST_ERRORS of task NAME after loading it. Usage: errors_of NAME
errors_of() {
	startup_task_load "$1"
	printf '%s\n' "$ST_ERRORS"
}

# ---------------------------------------------------------------------------------------------
# Values, settings and conditions
# ---------------------------------------------------------------------------------------------

@test "a value is accepted in any spelling and printed in its canonical one" {
	[ "$(startup_canon once-per-day EveryTime OncePerBoot OncePerDay Interval)" = OncePerDay ]
	[ "$(startup_canon ONCE_PER_BOOT EveryTime OncePerBoot OncePerDay Interval)" = OncePerBoot ]
	[ "$(startup_canon terminalopen SignIn TerminalOpen)" = TerminalOpen ]
	run startup_canon sometimes EveryTime OncePerDay
	[ "$status" -ne 0 ]
	[ "$(startup_bool On)" = 1 ]
	[ "$(startup_bool no)" = 0 ]
	run startup_bool maybe
	[ "$status" -ne 0 ]
	startup_is_number 1.5
	! startup_is_number -1 || false
	! startup_is_number abc || false
}

@test "settings before the first section: the last line wins, the default without one or without a file" {
	[ "$(startup_setting failure-report tab)" = tab ]
	conf "failure-report none" "[Task]" "failure-report tab"
	[ "$(startup_setting failure-report tab)" = none ]
	printf 'failure-report tab\n' >"$FOUNDATION_CONFIG_DIR/startup.local.conf"
	[ "$(startup_setting failure-report none)" = tab ]
}

@test "a condition line: TIMEOUT and INTERVAL are optional, the last line of a name wins, any case" {
	conf "condition Net 30 5 route -n get default" "condition Fast true" "condition fast 7 test -e /x"
	startup_condition_get NET
	[ "$STARTUP_CONDITION_TIMEOUT" = 30 ]
	[ "$STARTUP_CONDITION_INTERVAL" = 5 ]
	[ "$STARTUP_CONDITION_TEST" = "route -n get default" ]
	startup_condition_get Fast
	[ "$STARTUP_CONDITION_TIMEOUT" = 7 ]
	[ "$STARTUP_CONDITION_INTERVAL" = 2 ]
	[ "$STARTUP_CONDITION_TEST" = "test -e /x" ]
	run startup_condition_get Missing
	[ "$status" -ne 0 ]
	[ "$(startup_condition_names | paste -sd' ' -)" = "Net Fast" ]
}

@test "condition wait: met, not met, tested once with NOWAIT or a timeout of 0, unknown and empty count as not met" {
	conf "condition Up 5 0.1 true" "condition Down 0 false" "condition Slow 1 0.1 false" "condition Empty 5 2" \
		"condition Later 5 0.1 test -e $BATS_TEST_TMPDIR/flag"
	startup_condition_wait Up
	run startup_condition_wait Down
	[ "$status" -eq 1 ]
	run startup_condition_wait Slow 1
	[ "$status" -eq 1 ]
	run startup_condition_wait Slow
	[ "$status" -eq 1 ]
	run startup_condition_wait Nope
	[ "$status" -eq 1 ]
	run startup_condition_wait Empty
	[ "$status" -eq 1 ]
	# Met while it waits.
	(
		sleep 0.4
		touch "$BATS_TEST_TMPDIR/flag"
	) >/dev/null 2>&1 3>&- &
	startup_condition_wait Later
}

# ---------------------------------------------------------------------------------------------
# Loading a task
# ---------------------------------------------------------------------------------------------

@test "a task gets every default filled in" {
	conf "[Plain]" "trigger SignIn" "[WithCommand]" "command true" "trigger TerminalOpen"
	startup_task_load plain
	[ "$ST_NAME" = Plain ]
	[ "$ST_TRIGGERS" = SignIn ]
	[ "$ST_WINDOW" = Tab ]
	[ "$ST_KEEP_OPEN" = Always ]
	[ "$ST_PARALLEL" = 0 ]
	[ "$ST_FREQUENCY" = EveryTime ]
	[ "$ST_DAY_START_HOUR" = 6 ]
	[ "$ST_INTERVAL_HOURS" = 24 ]
	[ "$ST_ELEVATION" = None ]
	[ "$ST_TIMEOUT" = 600 ]
	[ "$ST_ENABLED" = 1 ]
	[ "$ST_IN_SCOPE" = 1 ]
	[ "$ST_VALID" = 1 ]
	[ -z "$ST_ERRORS" ]
	startup_task_load WithCommand
	[ "$ST_KEEP_OPEN" = OnFailure ]
	[ "$ST_COMMAND" = true ]
}

@test "every line of a task is read in any spelling; triggers split on spaces and commas, once each" {
	conf "condition Net 0 true" "condition Vpn 0 true" \
		"[Task]" "Command echo a b" "trigger signin,terminal-open SignIn" "requires Net, Vpn" "window HIDDEN" \
		"keep_open never" "parallel" "frequency once_per_day" "day-start-hour 09" "interval-hours 1.5" \
		"timeout 0" "enabled off"
	startup_task_load task
	[ "$ST_VALID" = 1 ]
	[ "$ST_COMMAND" = "echo a b" ]
	[ "$ST_TRIGGERS" = "SignIn TerminalOpen" ]
	[ "$ST_REQUIRES" = "Net Vpn" ]
	[ "$ST_WINDOW" = Hidden ]
	[ "$ST_KEEP_OPEN" = Never ]
	[ "$ST_PARALLEL" = 1 ]
	[ "$ST_FREQUENCY" = OncePerDay ]
	[ "$ST_DAY_START_HOUR" = 9 ]
	[ "$ST_INTERVAL_HOURS" = 1.5 ]
	[ "$ST_TIMEOUT" = 0 ]
	[ "$ST_ENABLED" = 0 ]
}

@test "validation: each broken rule makes the task invalid with its own problem" {
	conf "condition Net 0 true" \
		"[Key]" "trigger SignIn" "colour blue" \
		"[NoTrigger]" "command true" \
		"[Unlock]" "trigger Unlock" \
		"[Wake]" "trigger wake" \
		"[Boot]" "trigger Boot" \
		"[UnknownTrigger]" "trigger Sometimes" \
		"[Window]" "trigger SignIn" "window floating" \
		"[Frequency]" "trigger SignIn" "frequency weekly" \
		"[PromptHidden]" "trigger SignIn" "window hidden" "elevation prompt" \
		"[PromptTerminal]" "trigger SignIn TerminalOpen" "elevation prompt" \
		"[Relaunch]" "trigger SignIn" "elevation relaunch" \
		"[Requires]" "trigger SignIn" "requires Net Nope" \
		"[Hour]" "trigger SignIn" "day-start-hour 24" \
		"[Bad.Name]" "trigger SignIn"
	for case in "Key|[colour]" "NoTrigger|missing" "Unlock|[Unlock]" "Wake|[wake]" "Boot|[Boot]" \
		"UnknownTrigger|[Sometimes]" "Window|[floating]" "Frequency|[weekly]" "PromptHidden|hidden" \
		"PromptTerminal|TerminalOpen" "Relaunch|[relaunch]" "Requires|[Nope]" "Hour|[24]" "Bad.Name|[Bad.Name]"; do
		name=${case%%|*}
		startup_task_load "$name"
		[ "$ST_VALID" = 0 ] || {
			echo "$name loaded as valid"
			return 1
		}
		[[ $ST_ERRORS == *"${case#*|}"* ]] || {
			echo "$name: [$ST_ERRORS] does not name ${case#*|}"
			return 1
		}
	done
	# A rejected trigger is the one problem: no second "trigger is missing" on top of it.
	[ "$(errors_of Unlock | grep -c .)" -eq 1 ]
	[ "$(errors_of Requires | grep -c .)" -eq 1 ]
}

@test "a section with no line for this machine type, an empty one or none at all does not load" {
	conf "[Other]" "@Laptop command true" "@Laptop trigger SignIn" "[Empty]" "[Mixed]" "@Laptop trigger SignIn" "command true" "trigger TerminalOpen"
	export CONF_MACHINE_TYPE=Work
	run startup_task_load Other
	[ "$status" -ne 0 ]
	run startup_task_load Empty
	[ "$status" -ne 0 ]
	run startup_task_load Missing
	[ "$status" -ne 0 ]
	startup_task_load Mixed
	[ "$ST_TRIGGERS" = TerminalOpen ]
	export CONF_MACHINE_TYPE=Laptop
	startup_task_load Other
	[ "$ST_VALID" = 1 ]
	[ "$ST_TRIGGERS" = SignIn ]
}

@test "the overlay's section replaces the base one, its new sections come after the base ones" {
	conf "[One]" "trigger SignIn" "command base" "[Two]" "trigger SignIn"
	printf '[one]\ntrigger TerminalOpen\ncommand mine\n[Three]\ntrigger SignIn\n' >"$FOUNDATION_CONFIG_DIR/startup.local.conf"
	[ "$(startup_task_names | paste -sd' ' -)" = "One Two Three" ]
	startup_task_load One
	[ "$ST_COMMAND" = mine ]
	[ "$ST_TRIGGERS" = TerminalOpen ]
}

@test "scope: the machine types (CONF_MACHINE_TYPE), then the host name; both must match" {
	here=$(foundation_hostname)
	conf "[Machine]" "trigger SignIn" "machine Laptop, Work" \
		"[Host]" "trigger SignIn" "host No-Such-Host $here" \
		"[OtherHost]" "trigger SignIn" "host No-Such-Host" \
		"[Both]" "trigger SignIn" "machine Work" "host No-Such-Host"
	export CONF_MACHINE_TYPE=work
	startup_task_load Machine
	[ "$ST_IN_SCOPE" = 1 ]
	export CONF_MACHINE_TYPE=Desktop
	startup_task_load Machine
	[ "$ST_IN_SCOPE" = 0 ]
	[ "$ST_VALID" = 1 ]
	if [ -n "$here" ]; then
		startup_task_load Host
		[ "$ST_IN_SCOPE" = 1 ]
	fi
	startup_task_load OtherHost
	[ "$ST_IN_SCOPE" = 0 ]
	export CONF_MACHINE_TYPE=Work
	startup_task_load Both
	[ "$ST_IN_SCOPE" = 0 ]
}

# ---------------------------------------------------------------------------------------------
# Frequency
# ---------------------------------------------------------------------------------------------

@test "every-time is always due, and any frequency is due without a stamp" {
	stamp_at Task "$(date +%s)"
	[ "$(startup_next_due "$logs/.startup-task-Task.stamp" EveryTime 6 24)" = 0 ]
	for frequency in OncePerBoot OncePerDay Interval; do
		[ "$(startup_next_due "$logs/no-such.stamp" "$frequency" 6 24)" = 0 ]
	done
}

@test "once-per-day: a stamp from before the day started is due, one since then is due at the next boundary" {
	start=$(foundation_day_start 6)
	stamp_at Task $((start - 60))
	startup_due "$logs/.startup-task-Task.stamp" OncePerDay 6 24
	stamp_at Task $((start + 60))
	[ "$(startup_next_due "$logs/.startup-task-Task.stamp" OncePerDay 6 24)" -eq $((start + 86400)) ]
	! startup_due "$logs/.startup-task-Task.stamp" OncePerDay 6 24 || false
	# The day-start hour moves the boundary.
	start14=$(foundation_day_start 14)
	stamp_at Task $((start14 - 60))
	startup_due "$logs/.startup-task-Task.stamp" OncePerDay 14 24
}

@test "once-per-boot: due while the stamp is older than the machine's start (FOUNDATION_BOOT_TIME)" {
	now=$(date +%s)
	stamp_at Task $((now - 600))
	export FOUNDATION_BOOT_TIME=$((now - 300))
	startup_due "$logs/.startup-task-Task.stamp" OncePerBoot 6 24
	export FOUNDATION_BOOT_TIME=$((now - 900))
	[ "$(startup_next_due "$logs/.startup-task-Task.stamp" OncePerBoot 6 24)" = 9999999999 ]
	! startup_due "$logs/.startup-task-Task.stamp" OncePerBoot 6 24 || false
}

@test "once-per-boot: a boot time that cannot be read (0) makes the task due, never done for good" {
	stamp_at Task "$(date +%s)"
	export FOUNDATION_BOOT_TIME=0
	startup_due "$logs/.startup-task-Task.stamp" OncePerBoot 6 24
}

@test "interval: the stamp's age decides, not the day boundary; 0 hours is always due" {
	now=$(date +%s)
	stamp_at Task $((now - 3600))
	[ "$(startup_next_due "$logs/.startup-task-Task.stamp" Interval 6 2)" -eq $((now - 3600 + 7200)) ]
	! startup_due "$logs/.startup-task-Task.stamp" Interval 6 2 || false
	startup_due "$logs/.startup-task-Task.stamp" Interval 6 0.5
	[ "$(startup_next_due "$logs/.startup-task-Task.stamp" Interval 6 0)" = 0 ]
}

# ---------------------------------------------------------------------------------------------
# Lock and result file
# ---------------------------------------------------------------------------------------------

@test "the lock: taken when free, refused while a live process owns it, taken over from a dead owner" {
	lock=$logs/.startup-task-Task.lock
	startup_lock_take "$lock"
	[ "$(cat "$lock/pid")" = "$$" ]
	run startup_lock_take "$lock"
	[ "$status" -ne 0 ]
	echo 99999999 >"$lock/pid"
	startup_lock_take "$lock"
	[ "$(cat "$lock/pid")" = "$$" ]
}

@test "a lock without an owner is being claimed: refused while new, taken once ten minutes old" {
	lock=$logs/.startup-task-Task.lock
	mkdir -p "$lock"
	run startup_lock_take "$lock"
	[ "$status" -ne 0 ]
	touch -t 200001010000 "$lock"
	startup_lock_take "$lock"
	[ -f "$lock/pid" ]
}

@test "the result file: a record carries the status, this process and the reason; nothing without a file" {
	ST_RESULT_FILE=''
	startup_record Succeeded
	[ -z "$(ls -A "$logs")" ]
	ST_RESULT_FILE=$logs/.startup-task-Task.result
	startup_record Failed 'The command exited with status 3'
	IFS=$'\t' read -r status pid begun reason <"$ST_RESULT_FILE"
	[ "$status" = Failed ]
	[ "$pid" = "$$" ]
	[ -n "$begun" ]
	[ "$reason" = 'The command exited with status 3' ]
}

@test "waiting for a result: a final record ends the wait with its status, nothing is stamped by the waiter" {
	file=$logs/.startup-task-Task.result
	printf 'Failed\t%s\t%s\tbroken\n' "$$" "$(startup_process_start $$)" >"$file"
	startup_wait_result "$file" 5 "$logs/.startup-task-Task.stamp"
	[ "$ST_STATUS" = Failed ]
	[ "$ST_REASON" = broken ]
	[ ! -e "$logs/.startup-task-Task.stamp" ]
}

@test "waiting for a result: an empty start time keeps the reason in its own field" {
	file=$logs/.startup-task-Task.result
	printf 'Failed\t%s\t\tbroken badly\n' "$$" >"$file"
	startup_wait_result "$file" 5 "$logs/.startup-task-Task.stamp"
	[ "$ST_STATUS" = Failed ]
	[ "$ST_REASON" = "broken badly" ]
}

@test "waiting for a result: a fractional timeout is rounded up, never read as no limit" {
	file=$logs/.startup-task-Task.result
	printf 'Running\t%s\t%s\t\n' "$$" "$(startup_process_start $$)" >"$file"
	startup_wait_result "$file" 0.5 "$logs/.startup-task-Task.stamp"
	[ "$ST_STATUS" = TimedOut ]
}

@test "waiting for a result: a Running record whose process is gone is Ended, and the stamp is written" {
	file=$logs/.startup-task-Task.result
	printf 'Running\t99999999\t\t\n' >"$file"
	startup_wait_result "$file" 5 "$logs/.startup-task-Task.stamp"
	[ "$ST_STATUS" = Ended ]
	[ -s "$logs/.startup-task-Task.stamp" ]
	# A live process id that started at another time is another process: the task's shell is gone.
	rm "$logs/.startup-task-Task.stamp"
	printf 'Running\t%s\tMon Jan  1 00:00:00 2001\t\n' "$$" >"$file"
	startup_wait_result "$file" 5 "$logs/.startup-task-Task.stamp"
	[ "$ST_STATUS" = Ended ]
	[ -e "$logs/.startup-task-Task.stamp" ]
}

@test "waiting for a result: a live Running task or no record times out, and nothing is stamped" {
	file=$logs/.startup-task-Task.result
	printf 'Running\t%s\t%s\t\n' "$$" "$(startup_process_start $$)" >"$file"
	startup_wait_result "$file" 1 "$logs/.startup-task-Task.stamp"
	[ "$ST_STATUS" = TimedOut ]
	rm -f "$file"
	startup_wait_result "$file" 1 "$logs/.startup-task-Task.stamp"
	[ "$ST_STATUS" = TimedOut ]
	[ ! -e "$logs/.startup-task-Task.stamp" ]
}

@test "the statuses that leave something to report: Failed, Skipped and TimedOut" {
	for status in Failed Skipped TimedOut; do ! startup_status_ok "$status" || false; done
	for status in Succeeded Ended Started NotDue Disabled OutOfScope AlreadyRunning WouldRun; do startup_status_ok "$status"; done
}

# ---------------------------------------------------------------------------------------------
# The terminal-open gate
# ---------------------------------------------------------------------------------------------

# Line 1 of the gate, and its stamp lines.
gate_head() { head -n 1 "$logs/.startup-terminal-open"; }
gate_stamps() { tail -n +2 "$logs/.startup-terminal-open"; }

@test "the gate: none when no terminal-open task applies to this Mac" {
	export CONF_MACHINE_TYPE=Work
	conf "[SignInOnly]" "trigger SignIn" "command true" \
		"[Parked]" "trigger TerminalOpen" "enabled off" \
		"[Elsewhere]" "trigger TerminalOpen" "machine Laptop"
	startup_write_gate
	[ "$(gate_head)" = "none 0" ]
	[ -z "$(gate_stamps)" ]
	rm "$FOUNDATION_CONFIG_DIR/startup.conf"
	startup_write_gate
	[ "$(gate_head)" = "none 0" ]
}

@test "the gate: an every-time task is due at once and lists no stamp" {
	conf "[Always]" "trigger TerminalOpen" "command true"
	stamp_at Always "$(date +%s)"
	startup_write_gate
	[ "$(gate_head)" = "0 0" ]
	[ -z "$(gate_stamps)" ]
}

@test "the gate: a once-per-day task that ran is due at the next day boundary, which is also DAILY, and its stamp is listed" {
	conf "[Daily]" "trigger TerminalOpen" "command true" "frequency once-per-day" \
		"[Hourly]" "trigger TerminalOpen" "command true" "frequency interval" "interval-hours 48"
	stamp_at Daily "$(date +%s)"
	stamp_at Hourly "$(date +%s)"
	startup_write_gate
	boundary=$(($(foundation_day_start 6) + 86400))
	[ "$(gate_head)" = "$boundary $boundary" ]
	[ "$(gate_stamps)" = "$logs/.startup-task-Daily.stamp
$logs/.startup-task-Hourly.stamp" ]
}

@test "the gate: a once-per-day task without a stamp is due now, lists no stamp and still sets DAILY" {
	conf "[Daily]" "trigger TerminalOpen" "command true" "frequency once-per-day" "day-start-hour 0"
	startup_write_gate
	read -r next daily <<<"$(gate_head)"
	[ "$next" = 0 ]
	[ "$daily" -eq $(($(foundation_day_start 0) + 86400)) ]
	[ -z "$(gate_stamps)" ]
}

@test "the gate: a task skipped for a condition backs off; an invalid terminal-open task is due at once" {
	conf "[Offline]" "trigger TerminalOpen" "command true"
	before=$(date +%s)
	startup_write_gate Offline
	read -r next _ <<<"$(gate_head)"
	[ "$next" -ge $((before + STARTUP_BACKOFF)) ]
	[ "$next" -le $(($(date +%s) + STARTUP_BACKOFF)) ]
	conf "[Offline]" "trigger TerminalOpen" "command true" "frequency once-per-day" \
		"[Broken]" "trigger TerminalOpen" "colour blue"
	stamp_at Offline "$(date +%s)"
	startup_write_gate
	[ "$(gate_head | cut -d' ' -f1)" = 0 ]
}

# ---------------------------------------------------------------------------------------------
# The LaunchAgent
# ---------------------------------------------------------------------------------------------

@test "the agent: its label, the runner of this clone, the bash given, its log in the log folder, XML-escaped" {
	export FOUNDATION_LAUNCH_AGENTS_DIR=$BATS_TEST_TMPDIR/agents
	[ "$(startup_agents_dir)" = "$BATS_TEST_TMPDIR/agents" ]
	[ "$(startup_agent_label SignIn)" = foundation.StartupTasks-SignIn ]
	run startup_agent_plist SignIn '/opt/b&b/bin/bash'
	[ "$status" -eq 0 ]
	[[ $output == *"<string>foundation.StartupTasks-SignIn</string>"* ]]
	[[ $output == *"<string>/opt/b&amp;b/bin/bash</string>"* ]]
	[[ $output == *"<string>$FOUNDATION_UNIX/modules/Workflow/bin/Invoke-StartupTasks</string>"* ]]
	[[ $output == *"<string>--trigger</string>"* ]]
	[[ $output == *"<string>$logs/.startup-agent-SignIn.log</string>"* ]]
	[[ $output == *"<string>/opt/b&amp;b/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>"* ]]
	[[ $output == *"<key>AbandonProcessGroup</key>"* ]]
	if command -v plutil >/dev/null 2>&1; then
		printf '%s\n' "$output" >"$BATS_TEST_TMPDIR/agent.plist"
		plutil -lint "$BATS_TEST_TMPDIR/agent.plist"
	fi
}
