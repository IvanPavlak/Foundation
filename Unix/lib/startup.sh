# shellcheck shell=bash
# Startup tasks - the shared logic of Invoke-StartupTask (one task), Invoke-StartupTasks (the
# tasks of one trigger) and Set-StartupTasks (the LaunchAgent behind the SignIn trigger). What
# Windows spreads over Get-StartupTaskDefinitions, Test-StartupTaskDue, Test-StartupCondition,
# Start-StartupTaskShell, Wait-StartupTaskResult and the prompt check lives here, so the three
# commands can never disagree on the shape of a task.
#
# Configuration: Unix/config/startup.conf and its startup.local.conf overlay. Lines before the
# first section are settings (`failure-report tab|none`) and conditions
# (`condition NAME [TIMEOUT [INTERVAL]] TEST`); each `[Name]` section is one task. A task loaded
# with startup_task_load lives in the ST_* variables below; startup_run runs it.
#
# State, in the log folder (logfile_dir): .startup-task-NAME.stamp (written only after a run that
# succeeded; the frequency is measured from its time), .startup-task-NAME.lock (a folder holding
# the owner's process id: the same task never runs twice at once), .startup-task-NAME.result (how
# a task in another shell reports back) and .startup-terminal-open (the gate the shell rc reads
# with builtins only, see startup_write_gate).
#
# Needs lib/config.sh and lib/daystart.sh; a tab needs lib/terminal.sh and drivers/wezterm.sh.
# Written to run under bash 3.2 too, like the rest of lib/.

STARTUP_TRIGGERS='SignIn TerminalOpen'
# The WezTerm window the tabs of one startup share (Windows' WinuXStartup).
STARTUP_WINDOW=FoundationStartup
# Seconds a terminal-open task skipped for a condition waits before a new shell tries it again,
# so a Mac that is offline does not start a process in every shell.
STARTUP_BACKOFF=300

# The startup.conf path; fails when there is none.
startup_config() {
	conf_path startup.conf
}

# Folder of the state files; created when missing.
startup_state_dir() {
	local dir
	dir=$(logfile_dir)
	mkdir -p "$dir" 2>/dev/null
	printf '%s' "$dir"
}

# The current epoch second (bash 5 and zsh know it without a process).
startup_now() {
	printf '%s' "${EPOCHSECONDS:-$(date +%s)}"
}

# A value spelled any way (OncePerDay, once-per-day, ONCE_PER_DAY): lowercase, no - or _.
startup__norm() {
	local value
	value=$(foundation_lower "$1")
	value=${value//-/}
	printf '%s' "${value//_/}"
}

# Prints the candidate VALUE names, whatever its spelling; fails when it is none of them.
# Usage: startup_canon VALUE CANDIDATE...
startup_canon() {
	local want candidate
	want=$(startup__norm "$1")
	shift
	for candidate in "$@"; do
		if [ "$(startup__norm "$candidate")" = "$want" ]; then
			printf '%s' "$candidate"
			return 0
		fi
	done
	return 1
}

# on/off in any of its spellings: prints 1 or 0, fails on anything else.
startup_bool() {
	case $(foundation_lower "$1") in
		on | true | yes | 1) printf 1 ;;
		off | false | no | 0) printf 0 ;;
		*) return 1 ;;
	esac
}

# Is VALUE a number of 0 or more (a fraction allowed)?
startup_is_number() {
	[[ $1 =~ ^[0-9]+([.][0-9]+)?$ ]]
}

# A file's modification time in epoch seconds. GNU stat first: BSD stat rejects -c, but GNU stat
# takes `-f %m` as a file-system query and prints before failing.
startup_mtime() {
	stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null
}

# When this machine started, in epoch seconds; 0 when it cannot tell. FOUNDATION_BOOT_TIME
# overrides it (tests).
startup_boot_time() {
	local line
	if [ -n "${FOUNDATION_BOOT_TIME:-}" ]; then
		printf '%s' "$FOUNDATION_BOOT_TIME"
		return 0
	fi
	if line=$(sysctl -n kern.boottime 2>/dev/null) && [[ $line =~ sec\ =\ ([0-9]+) ]]; then
		printf '%s' "${BASH_REMATCH[1]}"
		return 0
	fi
	if [ -r /proc/stat ]; then
		awk '$1 == "btime" { print $2; found = 1; exit } END { if (!found) print 0 }' /proc/stat
		return 0
	fi
	printf 0
}

# ---------------------------------------------------------------------------------------------
# Settings and conditions (the lines before the first section)
# ---------------------------------------------------------------------------------------------

# The last `KEY VALUE` line before the first section for this machine type, else DEFAULT.
# Usage: startup_setting KEY DEFAULT
startup_setting() {
	local file value
	file=$(startup_config) || {
		printf '%s' "$2"
		return 0
	}
	value=$(conf_value "$file" "$1" 2>/dev/null) || value=$2
	printf '%s' "$value"
}

# The condition names, one per line, in file order, without duplicates.
startup_condition_names() {
	local file
	file=$(startup_config) || return 0
	conf_lines "$file" | awk 'tolower($1) == "condition" && NF >= 2 && !seen[tolower($2)]++ { print $2 }'
}

# Sets STARTUP_CONDITION_TIMEOUT, STARTUP_CONDITION_INTERVAL and STARTUP_CONDITION_TEST from the
# last `condition NAME [TIMEOUT [INTERVAL]] TEST` line of NAME (case-insensitive). Fails when no
# line names it. TIMEOUT defaults to 60 seconds, INTERVAL to 2.
startup_condition_get() {
	local file line kind name rest timeout interval first remainder found=1
	file=$(startup_config) || return 1
	while IFS= read -r line; do
		read -r kind name rest <<<"$line"
		foundation_ieq "$kind" condition || continue
		foundation_ieq "$name" "$1" || continue
		timeout=60
		interval=2
		read -r first remainder <<<"$rest"
		if startup_is_number "$first"; then
			timeout=$first
			rest=$remainder
			read -r first remainder <<<"$rest"
			if startup_is_number "$first"; then
				interval=$first
				rest=$remainder
			fi
		fi
		STARTUP_CONDITION_TIMEOUT=$timeout
		STARTUP_CONDITION_INTERVAL=$interval
		STARTUP_CONDITION_TEST=$rest
		found=0
	done < <(conf_lines "$file")
	return $found
}

# Waits until the condition NAME is met or its timeout passes. Its test is a bash command line,
# met when it exits 0 - the condition of an `if`; its output is not shown. With NOWAIT 1 it tests
# once. An unknown name or a condition without a test is reported and counts as not met, so a
# typo never lets a task run early. Usage: startup_condition_wait NAME [NOWAIT]
startup_condition_wait() {
	local name=$1 nowait=${2:-0} deadline announced=0 interval
	if ! startup_condition_get "$name"; then
		log_error "Unknown startup condition [$name] - add a condition line for it to startup.conf"
		return 1
	fi
	if [ -z "$STARTUP_CONDITION_TEST" ]; then
		log_error "Startup condition [$name] has no test command"
		return 1
	fi
	interval=$STARTUP_CONDITION_INTERVAL
	[ "$interval" != 0 ] || interval=2
	# Whole seconds, a fraction rounded up: 0.5 waits a second, it does not test once.
	case $STARTUP_CONDITION_TIMEOUT in
		*.*[1-9]*) deadline=$((SECONDS + ${STARTUP_CONDITION_TIMEOUT%%.*} + 1)) ;;
		*) deadline=$((SECONDS + ${STARTUP_CONDITION_TIMEOUT%%.*})) ;;
	esac
	while :; do
		"${BASH:-bash}" -c "$STARTUP_CONDITION_TEST" </dev/null >/dev/null 2>&1 && return 0
		[ "$nowait" = 1 ] && return 1
		[ "$SECONDS" -lt "$deadline" ] || return 1
		if [ "$announced" -eq 0 ]; then
			log_step "Waiting for [$name] (up to ${STARTUP_CONDITION_TIMEOUT%%.*} s)"
			announced=1
		fi
		sleep "$interval"
	done
}

# ---------------------------------------------------------------------------------------------
# Task definitions (one section each)
# ---------------------------------------------------------------------------------------------

# The task names, one per line, in file order (base, then the overlay's new ones).
startup_task_names() {
	local file
	file=$(startup_config) || return 0
	conf_sections "$file"
}

# Loads the task NAME from startup.conf into the ST_* variables, every default filled in and every
# rule checked:
#   ST_NAME ST_COMMAND ST_TRIGGERS (space-separated) ST_MACHINES ST_HOSTS ST_REQUIRES (space-
#   separated) ST_WINDOW (Tab|Hidden) ST_KEEP_OPEN (OnFailure|Always|Never) ST_PARALLEL (0|1)
#   ST_FREQUENCY (EveryTime|OncePerBoot|OncePerDay|Interval) ST_DAY_START_HOUR ST_INTERVAL_HOURS
#   ST_ELEVATION (None|Prompt) ST_TIMEOUT ST_ENABLED (0|1) ST_IN_SCOPE (0|1) ST_VALID (0|1)
#   ST_ERRORS (one problem per line)
# An invalid task (an unknown key or value, a missing trigger, a requires with no condition) is
# loaded with ST_VALID 0 and never runs. Fails when there is no section NAME, or when every line
# of it is for other machine types (@TYPE).
# Usage: startup_task_load NAME
startup_task_load() {
	local file lines line key value norm item canonical conditions machine host
	file=$(startup_config) || return 1
	lines=$(conf_section "$file" "$1") || return 1
	# A section whose every line is for other machine types does not exist on this one.
	[ -n "$lines" ] || return 1
	ST_NAME=$(conf_section_name "$file" "$1") || ST_NAME=$1
	ST_COMMAND=''
	ST_TRIGGERS=''
	ST_MACHINES=''
	ST_HOSTS=''
	ST_REQUIRES=''
	ST_WINDOW=Tab
	ST_KEEP_OPEN=''
	ST_PARALLEL=0
	ST_FREQUENCY=EveryTime
	ST_DAY_START_HOUR=6
	ST_INTERVAL_HOURS=24
	ST_ELEVATION=None
	ST_TIMEOUT=600
	ST_ENABLED=1
	ST_IN_SCOPE=1
	ST_ERRORS=''
	local trigger_rejected=0

	[[ $ST_NAME =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] ||
		startup__error "Name [$ST_NAME] may hold only letters, digits, '-' and '_'"

	while IFS= read -r line; do
		[ -n "$line" ] || continue
		read -r key value <<<"$line"
		norm=$(startup__norm "$key")
		case $norm in
			command) ST_COMMAND=$value ;;
			trigger)
				for item in ${value//,/ }; do
					case $(startup__norm "$item") in
						boot)
							startup__error "Trigger [Boot] is not supported: nothing can run before sign-in with a desktop - use SignIn"
							trigger_rejected=1
							;;
						unlock | wake)
							startup__error "Trigger [$item] has no native trigger on macOS - use SignIn or TerminalOpen"
							trigger_rejected=1
							;;
						*)
							if canonical=$(startup_canon "$item" $STARTUP_TRIGGERS); then
								case " $ST_TRIGGERS " in *" $canonical "*) ;; *) ST_TRIGGERS="${ST_TRIGGERS:+$ST_TRIGGERS }$canonical" ;; esac
							else
								startup__error "Unknown trigger [$item] - valid values: ${STARTUP_TRIGGERS// /, }"
								trigger_rejected=1
							fi
							;;
					esac
				done
				;;
			machine) ST_MACHINES="${ST_MACHINES:+$ST_MACHINES }$(printf '%s' "$value" | tr ',/' '  ')" ;;
			host | hostname) ST_HOSTS="${ST_HOSTS:+$ST_HOSTS }${value//,/ }" ;;
			requires) ST_REQUIRES="${ST_REQUIRES:+$ST_REQUIRES }${value//,/ }" ;;
			window)
				ST_WINDOW=$(startup_canon "$value" Tab Hidden) ||
					startup__error "Unknown window [$value] - valid values: tab, hidden (a TerminalOpen run is always inline)"
				;;
			keepopen)
				ST_KEEP_OPEN=$(startup_canon "$value" OnFailure Always Never) ||
					startup__error "Unknown keep-open [$value] - valid values: on-failure, always, never"
				;;
			parallel)
				ST_PARALLEL=$(startup_bool "${value:-on}") || {
					startup__error "Parallel [$value] is not on or off"
					ST_PARALLEL=0
				}
				;;
			enabled)
				ST_ENABLED=$(startup_bool "$value") || {
					startup__error "Enabled [$value] is not on or off"
					ST_ENABLED=1
				}
				;;
			frequency)
				ST_FREQUENCY=$(startup_canon "$value" EveryTime OncePerBoot OncePerDay Interval) ||
					startup__error "Unknown frequency [$value] - valid values: every-time, once-per-boot, once-per-day, interval"
				;;
			daystarthour)
				if foundation_whole_number "$value" 0 23; then ST_DAY_START_HOUR=$((10#$value)); else startup__error "Day-start-hour [$value] is not an hour from 0 to 23"; fi
				;;
			intervalhours)
				if startup_is_number "$value"; then ST_INTERVAL_HOURS=$value; else startup__error "Interval-hours [$value] is not a number"; fi
				;;
			timeout)
				if startup_is_number "$value"; then ST_TIMEOUT=$value; else startup__error "Timeout [$value] is not a number of seconds (0 or more)"; fi
				;;
			elevation)
				case $(startup__norm "$value") in
					relaunch | silent)
						startup__error "Elevation [$value] is not supported on macOS - use prompt (sudo asks in the task's tab)"
						;;
					*)
						ST_ELEVATION=$(startup_canon "$value" None Prompt) ||
							startup__error "Unknown elevation [$value] - valid values: none, prompt"
						;;
				esac
				;;
			*)
				startup__error "Unknown key [$key] - valid keys: command, trigger, machine, host, requires, window, keep-open, parallel, frequency, day-start-hour, interval-hours, elevation, timeout, enabled"
				;;
		esac
	done <<<"$lines"

	# The lists as single-spaced words: `requires Net, Vpn` is `Net Vpn`.
	ST_MACHINES=$(startup__words $ST_MACHINES)
	ST_HOSTS=$(startup__words $ST_HOSTS)
	ST_REQUIRES=$(startup__words $ST_REQUIRES)
	[ -n "$ST_TRIGGERS" ] || [ "$trigger_rejected" -eq 1 ] ||
		startup__error "Trigger is missing - one or several of: ${STARTUP_TRIGGERS// /, }"
	if [ -z "$ST_KEEP_OPEN" ]; then
		if [ -n "$ST_COMMAND" ]; then ST_KEEP_OPEN=OnFailure; else ST_KEEP_OPEN=Always; fi
	fi
	if [ "$ST_ELEVATION" = Prompt ]; then
		[ "$ST_WINDOW" != Hidden ] ||
			startup__error "Elevation [prompt] needs a tab: sudo cannot ask in a hidden window"
		case " $ST_TRIGGERS " in *" TerminalOpen "*)
			startup__error "Elevation [prompt] cannot be combined with the TerminalOpen trigger - use a second task"
			;;
		esac
	fi
	conditions=" $(startup_condition_names | tr '\n' ' ' | tr '[:upper:]' '[:lower:]') "
	for item in $ST_REQUIRES; do
		case $conditions in *" $(foundation_lower "$item") "*) ;; *)
			startup__error "Requires names [$item], which is no condition line of startup.conf"
			;;
		esac
	done

	# Scope: the machine type, then the host name; both must match when both are given.
	if [ -n "$ST_MACHINES" ]; then
		ST_IN_SCOPE=0
		machine=$(foundation_lower "${CONF_MACHINE_TYPE:-$(foundation_machine_type 2>/dev/null)}")
		for item in $ST_MACHINES; do
			[ "$(foundation_lower "$item")" = "$machine" ] && ST_IN_SCOPE=1
		done
	fi
	if [ "$ST_IN_SCOPE" -eq 1 ] && [ -n "$ST_HOSTS" ]; then
		ST_IN_SCOPE=0
		host=$(foundation_hostname)
		for item in $ST_HOSTS; do
			foundation_ieq "$item" "$host" && ST_IN_SCOPE=1
		done
	fi

	if [ -n "$ST_ERRORS" ]; then ST_VALID=0; else ST_VALID=1; fi
	return 0
}

# Its arguments joined by single spaces. Usage: startup__words WORD...
startup__words() {
	printf '%s' "$*"
}

startup__error() {
	ST_ERRORS="${ST_ERRORS:+$ST_ERRORS
}$1"
}

# Does the loaded task have TRIGGER?
startup_has_trigger() {
	case " $ST_TRIGGERS " in *" $1 "*) return 0 ;; esac
	return 1
}

# ---------------------------------------------------------------------------------------------
# Frequency
# ---------------------------------------------------------------------------------------------

# The epoch second a task is next due, from its stamp file: 0 when it is due now.
#   EveryTime   always 0; the stamp is not read
#   OncePerBoot 0 while the stamp is older than the machine's start, else never (9999999999)
#   OncePerDay  0 while the stamp is older than the start of the current day - today at
#               DAY-START-HOUR:00, or yesterday at that hour while it is earlier than that - else
#               the start of the next day
#   Interval    the stamp's time plus INTERVAL-HOURS (0 or less is always due)
# A missing stamp is always due. Usage: startup_next_due STAMP FREQUENCY DAY-START-HOUR INTERVAL-HOURS
startup_next_due() {
	local stamp=$1 frequency=$2 hour=${3:-6} hours=${4:-24} written start
	if [ "$frequency" = EveryTime ] || ! written=$(startup_mtime "$stamp"); then
		printf 0
		return 0
	fi
	case $frequency in
		OncePerBoot)
			# A boot time it cannot read (0) counts every run as a new boot, never as none.
			start=$(startup_boot_time)
			if [ "$start" -gt 0 ] && [ "$written" -ge "$start" ]; then printf 9999999999; else printf 0; fi
			;;
		Interval)
			awk -v w="$written" -v h="$hours" 'BEGIN { if (h + 0 <= 0) print 0; else printf "%d\n", w + h * 3600 }'
			;;
		*)
			start=$(foundation_day_start "$hour")
			if [ "$written" -ge "$start" ]; then printf '%s' $((start + 86400)); else printf 0; fi
			;;
	esac
}

# Is a task due now? Usage: startup_due STAMP FREQUENCY DAY-START-HOUR INTERVAL-HOURS
startup_due() {
	[ "$(startup_next_due "$@")" -le "$(startup_now)" ]
}

# ---------------------------------------------------------------------------------------------
# Lock and result file
# ---------------------------------------------------------------------------------------------

# Takes the lock folder LOCK. mkdir is atomic: of several processes starting together exactly
# one creates it. A lock whose owner process is gone was left by a run that died; one without an
# owner yet is being claimed, unless it is ten minutes old. Fails when another process holds it.
# Usage: startup_lock_take LOCK
startup_lock_take() {
	local lock=$1 owner created
	if ! mkdir "$lock" 2>/dev/null; then
		owner=$(cat "$lock/pid" 2>/dev/null) || owner=''
		if [ -n "$owner" ]; then
			kill -0 "$owner" 2>/dev/null && return 1
		else
			created=$(startup_mtime "$lock") || created=$(startup_now)
			[ $(($(startup_now) - created)) -lt 600 ] && return 1
		fi
		rm -rf "$lock"
		mkdir "$lock" 2>/dev/null || return 1
	fi
	printf '%s\n' "$$" >"$lock/pid"
}

# When process PID started, as ps prints it; empty when it is gone.
startup_process_start() {
	ps -o lstart= -p "$1" 2>/dev/null | sed 's/^ *//; s/ *$//'
}

# Writes STATUS and REASON to the result file ST_RESULT_FILE (nothing without one), with this
# process's id and start time: STATUS<TAB>PID<TAB>STARTED<TAB>REASON.
# Usage: startup_record STATUS [REASON]
startup_record() {
	[ -n "${ST_RESULT_FILE:-}" ] || return 0
	printf '%s\t%s\t%s\t%s\n' "$1" "$$" "$(startup_process_start $$)" "${2:-}" >"$ST_RESULT_FILE.$$" 2>/dev/null &&
		mv -f "$ST_RESULT_FILE.$$" "$ST_RESULT_FILE" 2>/dev/null || true
}

# Waits for a task that runs in another shell and sets ST_STATUS and ST_REASON:
#   - a final record in the result file: its status and reason
#   - a Running record whose process is gone: the task closed its own shell, so it counts as
#     finished (Ended) and the stamp is written, as after a success
#   - TIMEOUT seconds passed (0 waits without limit): TimedOut; nothing is stopped
# Usage: startup_wait_result RESULT-FILE TIMEOUT STAMP
startup_wait_result() {
	local file=$1 timeout=${2:-600} stamp=$3 started status pid begun reason line
	started=$(startup_now)
	# Whole seconds, a fraction rounded up: 0.5 must not become 0, "without limit".
	case $timeout in *.*[1-9]*) timeout=$((${timeout%%.*} + 1)) ;; *) timeout=${timeout%%.*} ;; esac
	ST_STATUS=TimedOut
	ST_REASON="No result after ${timeout} s - the task was left running"
	while :; do
		# Split on the tabs by hand: a tab is IFS whitespace to read, so an empty field would
		# vanish and shift the reason into the start time.
		line=''
		[ -r "$file" ] && IFS= read -r line <"$file"
		status=${line%%$'\t'*}
		line=${line#"$status"}
		line=${line#$'\t'}
		pid=${line%%$'\t'*}
		line=${line#"$pid"}
		line=${line#$'\t'}
		begun=${line%%$'\t'*}
		reason=${line#"$begun"}
		reason=${reason#$'\t'}
		if [ -n "$status" ]; then
			if [ "$status" != Running ]; then
				ST_STATUS=$status
				ST_REASON=$reason
				return 0
			fi
			# Alive means: a process with that id that started when the record says it did.
			if ! kill -0 "$pid" 2>/dev/null || { [ -n "$begun" ] && [ "$(startup_process_start "$pid")" != "$begun" ]; }; then
				ST_STATUS=Ended
				ST_REASON="The task's shell closed before it reported a result"
				[ -z "$stamp" ] || date '+%Y-%m-%dT%H:%M:%S%z' >"$stamp" 2>/dev/null || true
				return 0
			fi
		fi
		if [ "$timeout" -gt 0 ] && [ $(($(startup_now) - started)) -ge "$timeout" ]; then
			return 0
		fi
		sleep "${STARTUP_POLL:-0.25}"
	done
}

# ---------------------------------------------------------------------------------------------
# Running one task
# ---------------------------------------------------------------------------------------------

# The arguments of the Invoke-StartupTask run in the task's own shell, in STARTUP_CHILD_ARGS: the
# loaded task with --window current and the result file, forced when FORCE is 1 (the gates are
# behind it). Usage: startup__child_args TRIGGER FORCE
startup__child_args() {
	local item
	STARTUP_CHILD_ARGS=("$ST_NAME" --command "$ST_COMMAND" --trigger "$1" --window current
		--frequency "$ST_FREQUENCY" --day-start-hour "$ST_DAY_START_HOUR"
		--interval-hours "$ST_INTERVAL_HOURS" --elevation "$ST_ELEVATION" --result-file "$ST_RESULT_FILE")
	for item in $ST_REQUIRES; do STARTUP_CHILD_ARGS+=(--requires "$item"); done
	[ "$2" = 1 ] && STARTUP_CHILD_ARGS+=(--force)
	return 0
}

# Starts the shell the loaded task runs in and returns without waiting for it.
#   Hidden: a background process with no terminal, its output in the session log; it outlives
#   the runner (the LaunchAgent keeps its process group alive).
#   Tab: a WezTerm tab in the FoundationStartup window (opened, or joined while it is open). The
#   tab's shell runs the task and closes itself as ST_KEEP_OPEN says: OnFailure closes it unless the
#   task failed, was skipped or timed out; Never always closes it; Always leaves it. A task with a
#   command marks its shell as a task shell, so the terminal-open tasks never run in it; a task
#   without one is a plain terminal and runs them as any other.
# Usage: startup_start_shell TRIGGER FORCE
startup_start_shell() {
	local runner line target pane window skip=0
	runner=$FOUNDATION_UNIX/modules/Workflow/bin/Invoke-StartupTask
	startup__child_args "$1" "$2"
	if [ "${ST_RUN_WINDOW:-$ST_WINDOW}" = Hidden ]; then
		log_debug "[startup] starting a hidden shell for [$ST_NAME]"
		FOUNDATION_STARTUP_TASK_SHELL=1 nohup "${BASH:-bash}" "$runner" "${STARTUP_CHILD_ARGS[@]}" \
			</dev/null >>"${FOUNDATION_LOG_FILE:-/dev/null}" 2>&1 &
		# Not a job of this runner: no "Killed" notice when the task ends its own process.
		disown "$!" 2>/dev/null || true
		return 0
	fi
	foundation_load drivers/wezterm terminal
	line="$(printf '%q ' "$runner" "${STARTUP_CHILD_ARGS[@]}")"
	line=${line% }
	if [ -n "$ST_COMMAND" ]; then
		# The shell starts without its startup run (it would run the terminal-open tasks before
		# the task is typed) and is marked before the task starts.
		skip=1
		line="export FOUNDATION_STARTUP_TASK_SHELL=1; $line"
		case $ST_KEEP_OPEN in
			Never) line="$line; exit" ;;
			OnFailure) line="$line && exit" ;;
		esac
	fi
	target=$(term_named_window "$STARTUP_WINDOW") || target=new
	log_debug "[startup] opening a tab for [$ST_NAME] in window [$STARTUP_WINDOW] => $target (keep open: $ST_KEEP_OPEN)"
	pane=$(printf '%s\t%s\t%s\n' "$ST_NAME" "$HOME" "$line" | term_open_tabs "$target" "$skip") || return 1
	pane=${pane%%$'\n'*}
	[ -n "$pane" ] || return 1
	if [ "$target" = new ]; then
		window=$(wt_pane_window "$pane")
		[ -z "$window" ] || term_remember_window "$STARTUP_WINDOW" "$window" || true
	fi
	return 0
}

# Runs the loaded task (startup_task_load, or ST_* set by hand) and sets ST_STATUS and ST_REASON.
# Options, read from these variables:
#   ST_RUN_TRIGGER   what caused the run: Manual (default), SignIn or TerminalOpen
#   ST_RUN_WINDOW    Current (default) runs it in this process; Tab or Hidden starts a shell for it
#                    and waits for its result up to ST_TIMEOUT, or returns Started with ST_PARALLEL 1
#   ST_FORCE         1 passes the enabled and frequency gates, never the scope
#   ST_DRY_RUN       1 runs nothing: WouldRun, with the conditions it would wait for
#   ST_NO_WAIT       1 tests each condition once and skips quietly when one is not met
#   ST_RESULT_FILE   where an inline run reports to the shell that started it
#   ST_CHECK_SCOPE   0 skips the scope gate (a task shell: its starter checked it)
# In order: the gates (Disabled, OutOfScope, NotDue); the lock (AlreadyRunning) and the frequency
# again under it; the conditions (Skipped); elevation prompt asks sudo once; the command, run by
# bash, has Failed when it exits non-zero. Only a run that Succeeded writes the stamp.
startup_run() {
	local dir stamp lock status reason name unmet='' exit_code
	ST_STATUS=''
	ST_REASON=''
	dir=$(startup_state_dir)
	stamp=$dir/.startup-task-$ST_NAME.stamp
	lock=$dir/.startup-task-$ST_NAME.lock

	if [ "${ST_ENABLED:-1}" != 1 ] && [ "${ST_FORCE:-0}" != 1 ]; then
		startup__finish Disabled 'The task is not enabled'
		return 0
	fi
	if [ "${ST_CHECK_SCOPE:-1}" = 1 ] && [ "${ST_IN_SCOPE:-1}" != 1 ]; then
		startup__finish OutOfScope "Machine [${ST_MACHINES:-any}] and host [${ST_HOSTS:-any}] do not cover this Mac"
		return 0
	fi
	if [ "${ST_FORCE:-0}" != 1 ] && ! startup_due "$stamp" "$ST_FREQUENCY" "$ST_DAY_START_HOUR" "$ST_INTERVAL_HOURS"; then
		startup__finish NotDue "Already ran ($ST_FREQUENCY)"
		return 0
	fi

	if [ "${ST_DRY_RUN:-0}" = 1 ]; then
		for name in $ST_REQUIRES; do
			startup_condition_wait "$name" 1 2>/dev/null || unmet="${unmet:+$unmet, }$name"
		done
		ST_STATUS=WouldRun
		ST_REASON=${unmet:+Would wait for: $unmet}
		return 0
	fi

	if [ "${ST_RUN_WINDOW:-Current}" != Current ]; then
		ST_RESULT_FILE=$dir/.startup-task-$ST_NAME.result
		rm -f "$ST_RESULT_FILE"
		if ! startup_start_shell "${ST_RUN_TRIGGER:-Manual}" "${ST_FORCE:-0}"; then
			ST_STATUS=Failed
			ST_REASON='Could not start its shell'
			log_error "Startup task [$ST_NAME] could not be started"
			return 0
		fi
		if [ "${ST_PARALLEL:-0}" = 1 ]; then
			ST_STATUS=Started
			return 0
		fi
		startup_wait_result "$ST_RESULT_FILE" "$ST_TIMEOUT" "$stamp"
		return 0
	fi

	# Inline run.
	if ! startup_lock_take "$lock"; then
		startup__finish AlreadyRunning 'Another shell is running this task'
		return 0
	fi
	status=Failed
	reason=''
	while :; do
		# Again under the lock: another shell may have finished a run in between.
		if [ "${ST_FORCE:-0}" != 1 ] && ! startup_due "$stamp" "$ST_FREQUENCY" "$ST_DAY_START_HOUR" "$ST_INTERVAL_HOURS"; then
			status=NotDue
			reason="Already ran ($ST_FREQUENCY)"
			break
		fi
		startup_record Running
		[ -z "${ST_RESULT_FILE:-}" ] || log_step "Startup task [$ST_NAME]"
		for name in $ST_REQUIRES; do
			if ! startup_condition_wait "$name" "${ST_NO_WAIT:-0}"; then
				unmet=$name
				break
			fi
		done
		if [ -n "$unmet" ]; then
			status=Skipped
			if [ "${ST_NO_WAIT:-0}" = 1 ]; then
				reason="Condition [$unmet] is not met"
				log_debug "[startup] [$ST_NAME] skipped - $reason"
			else
				reason="Condition [$unmet] was not met in time"
				log_warning "Startup task [$ST_NAME] skipped - $reason"
			fi
			break
		fi
		if [ -z "$ST_COMMAND" ]; then
			status=Succeeded
			break
		fi
		if [ "$ST_ELEVATION" = Prompt ] && ! sudo -v; then
			status=Failed
			reason='sudo did not grant administrator rights'
			log_error "Startup task [$ST_NAME] failed - $reason"
			break
		fi
		FOUNDATION_STARTUP_TASK=$ST_NAME "${BASH:-bash}" -c "$ST_COMMAND"
		exit_code=$?
		if [ "$exit_code" -eq 0 ]; then
			status=Succeeded
		else
			status=Failed
			reason="The command exited with status $exit_code"
			log_error "Startup task [$ST_NAME] failed - $reason"
		fi
		break
	done
	if [ "$status" = Succeeded ]; then
		date '+%Y-%m-%dT%H:%M:%S%z' >"$stamp" 2>/dev/null || log_debug "[startup] could not write the stamp of [$ST_NAME]"
	fi
	rm -rf "$lock"
	startup__finish "$status" "$reason"
}

# Sets ST_STATUS and ST_REASON and writes them to the result file. Usage: startup__finish STATUS REASON
# shellcheck disable=SC2034 # read by the callers of startup_run
startup__finish() {
	ST_STATUS=$1
	ST_REASON=$2
	startup_record "$1" "$2"
}

# Is STATUS one that leaves nothing to report? (Failed, Skipped and TimedOut are problems.)
startup_status_ok() {
	case $1 in Failed | Skipped | TimedOut) return 1 ;; esac
	return 0
}

# ---------------------------------------------------------------------------------------------
# The terminal-open gate
# ---------------------------------------------------------------------------------------------

# Writes the gate the shell rc reads with builtins only (.startup-terminal-open), so a shell
# starts and draws prompts without a process until a terminal-open task is due:
#   line 1   NEXT DAILY - NEXT is the epoch second the first terminal-open task is due (0: now),
#            or `none` when no terminal-open task applies to this Mac; DAILY is the next day
#            boundary of a once-per-day terminal-open task (the prompt check of a shell left open
#            overnight), 0 when there is none
#   line 2+  the stamp files those times were read from: a stamp that is gone makes the gate due
# A task named in SKIPPED (skipped for a condition in this run) is due again after
# STARTUP_BACKOFF seconds, not at once, so an offline Mac does not start a process in every shell.
# An invalid terminal-open task is due at once: it is reported in every shell until it is fixed.
# The shell also runs the tasks when startup.conf or machines.conf (or an overlay) is newer than
# the gate. Usage: startup_write_gate [SKIPPED...]
startup_write_gate() {
	local dir gate now next=none daily=0 name task_next stamp stamps='' skipped=" $* " boundary
	dir=$(startup_state_dir)
	gate=$dir/.startup-terminal-open
	now=$(startup_now)
	while IFS= read -r name; do
		[ -n "$name" ] || continue
		startup_task_load "$name" || continue
		startup_has_trigger TerminalOpen || continue
		if [ "$ST_VALID" != 1 ]; then
			task_next=0
		else
			[ "$ST_ENABLED" = 1 ] && [ "$ST_IN_SCOPE" = 1 ] || continue
			stamp=$dir/.startup-task-$ST_NAME.stamp
			case $skipped in
				*" $ST_NAME "*) task_next=$((now + STARTUP_BACKOFF)) ;;
				*) task_next=$(startup_next_due "$stamp" "$ST_FREQUENCY" "$ST_DAY_START_HOUR" "$ST_INTERVAL_HOURS") ;;
			esac
			[ "$ST_FREQUENCY" = EveryTime ] || [ ! -e "$stamp" ] || stamps="$stamps$stamp
"
			if [ "$ST_FREQUENCY" = OncePerDay ]; then
				boundary=$(($(foundation_day_start "$ST_DAY_START_HOUR") + 86400))
				if [ "$daily" -eq 0 ] || [ "$boundary" -lt "$daily" ]; then daily=$boundary; fi
			fi
		fi
		if [ "$next" = none ] || [ "$task_next" -lt "$next" ]; then next=$task_next; fi
	done < <(startup_task_names)
	{
		printf '%s %s\n' "$next" "$daily"
		printf '%s' "$stamps"
	} >"$gate.$$" 2>/dev/null && mv -f "$gate.$$" "$gate" 2>/dev/null || rm -f "$gate.$$"
	return 0
}

# ---------------------------------------------------------------------------------------------
# The LaunchAgent (Set-StartupTasks)
# ---------------------------------------------------------------------------------------------

# Where the LaunchAgents live (FOUNDATION_LAUNCH_AGENTS_DIR overrides it for tests).
startup_agents_dir() {
	printf '%s' "${FOUNDATION_LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
}

# The label of the LaunchAgent of TRIGGER.
startup_agent_label() {
	printf 'foundation.StartupTasks-%s' "$1"
}

startup__xml() {
	local text=$1
	text=${text//&/&amp;}
	text=${text//</&lt;}
	printf '%s' "${text//>/&gt;}"
}

# The property list of the LaunchAgent that runs `Invoke-StartupTasks --trigger TRIGGER` at
# sign-in: no window, Homebrew bash (BASH-PATH) and the runner of this clone, its own output in
# the log folder, and its process group left alone when the runner exits, so a hidden task or a
# WezTerm it started outlives it. Usage: startup_agent_plist TRIGGER BASH-PATH
startup_agent_plist() {
	local trigger=$1 bash_path=$2 label runner log path
	label=$(startup_agent_label "$trigger")
	runner=$FOUNDATION_UNIX/modules/Workflow/bin/Invoke-StartupTasks
	log=$(logfile_dir)/.startup-agent-$trigger.log
	path="${bash_path%/*}:/usr/bin:/bin:/usr/sbin:/sbin"
	cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$label</string>
	<key>ProgramArguments</key>
	<array>
		<string>$(startup__xml "$bash_path")</string>
		<string>$(startup__xml "$runner")</string>
		<string>--trigger</string>
		<string>$trigger</string>
	</array>
	<key>EnvironmentVariables</key>
	<dict>
		<key>PATH</key>
		<string>$(startup__xml "$path")</string>
		<key>LANG</key>
		<string>$(startup__xml "${LANG:-en_US.UTF-8}")</string>
	</dict>
	<key>RunAtLoad</key>
	<true/>
	<key>LimitLoadToSessionType</key>
	<string>Aqua</string>
	<key>ProcessType</key>
	<string>Interactive</string>
	<key>AbandonProcessGroup</key>
	<true/>
	<key>StandardOutPath</key>
	<string>$(startup__xml "$log")</string>
	<key>StandardErrorPath</key>
	<string>$(startup__xml "$log")</string>
</dict>
</plist>
EOF
}
