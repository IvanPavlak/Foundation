#!/usr/bin/env bats
# File logging: a module command opens one session log that nested commands share, errors also
# reach Errors.log, FOUNDATION_LOGGING=off writes nothing, retention by age, count and size (a dry
# run naming each file once), and logging.conf is read as every config file is (overlay, @TYPE,
# -LINE), even before config.sh loads. Also the console side: debug lines only at verbose, the
# quiet level, the level, directory, error-file and color lines. The command that logs is
# Test-MachineOnline against a ping stand-in, so no packet leaves.

load helpers

setup() {
	setup_foundation
	export FOUNDATION_LOG_DIR="$BATS_TEST_TMPDIR/logs"
	unset FOUNDATION_LOGGING FOUNDATION_LOG_FILE
	# A session started here may run the maintenance sweep in the background (a config without a
	# maintenance line has it on): it must only ever see throwaway folders.
	export FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/backups FOUNDATION_TEST_RESULTS=$BATS_TEST_TMPDIR/results TMPDIR=$BATS_TEST_TMPDIR/tmp
	mkdir -p "$TMPDIR"
	# 127.0.0.1 answers, anything else does not; ping's last argument is the address. The real
	# ping made these cases depend on the Mac (firewall stealth mode drops even a ping to
	# 127.0.0.1) and on DNS.
	stub_tool ping 'for a in "$@"; do last=$a; done; [ "$last" = 127.0.0.1 ]'
	cmd=$UNIX_DIR/modules/System/bin/Test-MachineOnline
}

@test "a command writes one session log with its lines; errors also reach Errors.log" {
	run "${BASH:-bash}" "$cmd" --machine NoSuchMachine-for-tests.invalid
	logs=("$FOUNDATION_LOG_DIR"/Session_*_Test-MachineOnline.log)
	[ ${#logs[@]} -eq 1 ]
	[ -f "${logs[0]}" ]
	grep -q '^# Test-MachineOnline --machine' "${logs[0]}"
	grep -q '\[WARNING\] .*offline or unreachable' "${logs[0]}"
	run "${BASH:-bash}" "$cmd" --timeout-seconds
	grep -q '\[ERROR\]' "$FOUNDATION_LOG_DIR/Errors.log"
}

@test "a nested command writes into the caller's session" {
	export FOUNDATION_LOG_FILE="$BATS_TEST_TMPDIR/outer.log"
	: >"$FOUNDATION_LOG_FILE"
	run "${BASH:-bash}" "$cmd" 127.0.0.1
	grep -q 'online' "$FOUNDATION_LOG_FILE"
	[ ! -d "$FOUNDATION_LOG_DIR" ] || [ -z "$(ls "$FOUNDATION_LOG_DIR" | grep Session_)" ]
}

@test "FOUNDATION_LOGGING=off writes nothing" {
	FOUNDATION_LOGGING=off run "${BASH:-bash}" "$cmd" 127.0.0.1
	[ ! -d "$FOUNDATION_LOG_DIR" ] || [ -z "$(ls -A "$FOUNDATION_LOG_DIR")" ]
}

@test "retention keeps the newest max-session-files and never touches Pinned" {
	mkdir -p "$FOUNDATION_LOG_DIR/Pinned"
	for i in $(seq -w 1 25); do : >"$FOUNDATION_LOG_DIR/Session_2026-01-${i}_00-00-00_X.log"; done
	: >"$FOUNDATION_LOG_DIR/Pinned/Session_2020-01-01_00-00-00_Keep.log"
	. "$UNIX_DIR/lib/logfile.sh"
	logfile_prune 0 >/dev/null
	[ "$(ls "$FOUNDATION_LOG_DIR" | grep -c '^Session_')" -eq 20 ]
	[ -f "$FOUNDATION_LOG_DIR/Session_2026-01-25_00-00-00_X.log" ]
	[ ! -f "$FOUNDATION_LOG_DIR/Session_2026-01-01_00-00-00_X.log" ]
	[ -f "$FOUNDATION_LOG_DIR/Pinned/Session_2020-01-01_00-00-00_Keep.log" ]
}

@test "logging off in logging.local.conf writes nothing, though the base file says on" {
	use_empty_config
	printf 'logging on\n' >"$FOUNDATION_CONFIG_DIR/logging.conf"
	printf 'logging off\n' >"$FOUNDATION_CONFIG_DIR/logging.local.conf"
	run "${BASH:-bash}" "$cmd" 127.0.0.1
	[ ! -d "$FOUNDATION_LOG_DIR" ] || [ -z "$(ls -A "$FOUNDATION_LOG_DIR")" ]
}

@test "an @TYPE logging off line for this machine type writes nothing; another type's line does not apply" {
	use_empty_config
	export FOUNDATION_MACHINE_TYPE=Work
	printf 'logging on\n@Work logging off\n' >"$FOUNDATION_CONFIG_DIR/logging.conf"
	run "${BASH:-bash}" "$cmd" 127.0.0.1
	[ ! -d "$FOUNDATION_LOG_DIR" ] || [ -z "$(ls -A "$FOUNDATION_LOG_DIR")" ]
	printf 'logging on\n@Laptop logging off\n' >"$FOUNDATION_CONFIG_DIR/logging.conf"
	run "${BASH:-bash}" "$cmd" 127.0.0.1
	logs=("$FOUNDATION_LOG_DIR"/Session_*_Test-MachineOnline.log)
	[ -f "${logs[0]}" ]
}

@test "logfile_setting reads as conf_value does (@TYPE, -LINE, overlay) before lib/config.sh is loaded, value only on stdout" {
	use_empty_config
	printf 'max-age-days 7\n@Work max-age-days 3\nlogging off\n' >"$FOUNDATION_CONFIG_DIR/logging.conf"
	printf -- '-logging off\n@Laptop max-age-days 1\n' >"$FOUNDATION_CONFIG_DIR/logging.local.conf"
	# A shell with only log.sh and logfile.sh, the state foundation.sh opens a session in.
	run env FOUNDATION_MACHINE_TYPE=Work "${BASH:-bash}" -c '. "$1/lib/log.sh"; . "$1/lib/logfile.sh"
		[ "$(type -t conf_value)" != function ] || exit 9
		printf "%s|%s|%s" "$(logfile_setting max-age-days 7)" "$(logfile_setting logging on)" "$(logfile_setting max-session-files 20)"
		[ "$(type -t conf_value)" != function ] || exit 8' _ "$UNIX_DIR"
	[ "$status" -eq 0 ]
	[ "$output" = "3|on|20" ]
}

@test "retention removes session logs older than max-age-days; a dry run names each file once" {
	use_empty_config
	printf 'max-age-days 7\nmax-session-files 2\nmax-total-size-mb 0\n' >"$FOUNDATION_CONFIG_DIR/logging.conf"
	mkdir -p "$FOUNDATION_LOG_DIR"
	for i in 1 2 3 4 5; do : >"$FOUNDATION_LOG_DIR/Session_2026-01-0${i}_00-00-00_X.log"; done
	touch -t 202001010000 "$FOUNDATION_LOG_DIR"/Session_2026-01-0[12]_00-00-00_X.log
	run logfile_prune 1
	[ "$status" -eq 0 ]
	# The two old files once (by age); the count step sees only the three left and names one.
	[ "${#lines[@]}" -eq 3 ]
	[ "$(grep -c 'Session_2026-01-01' <<<"$output")" -eq 1 ]
	[[ $output == *"would remove Session_2026-01-01_00-00-00_X.log (older than 7 days)"* ]]
	[[ $output == *"would remove Session_2026-01-02_00-00-00_X.log (older than 7 days)"* ]]
	[[ $output == *"would remove Session_2026-01-03_00-00-00_X.log (more than 2 sessions)"* ]]
	sessions=("$FOUNDATION_LOG_DIR"/Session_*.log)
	[ ${#sessions[@]} -eq 5 ]
	logfile_prune 0 >/dev/null
	[ "$(ls "$FOUNDATION_LOG_DIR")" = "$(printf 'Session_2026-01-04_00-00-00_X.log\nSession_2026-01-05_00-00-00_X.log')" ]
}

@test "max-total-size-mb removes the oldest session logs first and never the current session" {
	use_empty_config
	printf 'max-age-days 0\nmax-session-files 0\nmax-total-size-mb 1\n' >"$FOUNDATION_CONFIG_DIR/logging.conf"
	mkdir -p "$FOUNDATION_LOG_DIR"
	# About 1.2 MB together, 400 KB each.
	for i in 1 2 3; do head -c 409600 /dev/zero | tr '\0' x >"$FOUNDATION_LOG_DIR/Session_2026-01-0${i}_00-00-00_X.log"; done
	export FOUNDATION_LOG_FILE=$FOUNDATION_LOG_DIR/Session_2026-01-01_00-00-00_X.log
	run logfile_prune 0
	[ "$status" -eq 0 ]
	[[ $output == *"removed Session_2026-01-02_00-00-00_X.log (logs over 1 MB)"* ]]
	[ -f "$FOUNDATION_LOG_DIR/Session_2026-01-01_00-00-00_X.log" ]
	[ ! -f "$FOUNDATION_LOG_DIR/Session_2026-01-02_00-00-00_X.log" ]
	[ -f "$FOUNDATION_LOG_DIR/Session_2026-01-03_00-00-00_X.log" ]
}

@test "a debug line reaches the session log, and the console only at the verbose level" {
	export FOUNDATION_LOG_FILE=$BATS_TEST_TMPDIR/session.log
	: >"$FOUNDATION_LOG_FILE"
	FOUNDATION_LOG_LEVEL=normal log_debug "first probe" 2>"$BATS_TEST_TMPDIR/stderr"
	grep -qE '^[0-9:]{8} \[DEBUG\] first probe$' "$FOUNDATION_LOG_FILE"
	[ ! -s "$BATS_TEST_TMPDIR/stderr" ]
	FOUNDATION_LOG_LEVEL=verbose log_debug "second probe" 2>"$BATS_TEST_TMPDIR/stderr"
	grep -qE '^[0-9:]{8} \[DEBUG\] second probe$' "$FOUNDATION_LOG_FILE"
	grep -qF '[debug] second probe' "$BATS_TEST_TMPDIR/stderr"
}

@test "log_segments writes one STEP line of all its parts" {
	export FOUNDATION_LOG_FILE=$BATS_TEST_TMPDIR/session.log
	: >"$FOUNDATION_LOG_FILE"
	run log_segments step a success b
	[ "$output" = $'\nab' ]
	[ "$(wc -l <"$FOUNDATION_LOG_FILE" | tr -d ' ')" -eq 1 ]
	grep -qE '^[0-9:]{8} \[STEP\] ab$' "$FOUNDATION_LOG_FILE"
}

@test "the quiet level prints only warnings and errors; the session log still gets every line" {
	export FOUNDATION_LOG_FILE=$BATS_TEST_TMPDIR/session.log
	: >"$FOUNDATION_LOG_FILE"
	output=$(
		export FOUNDATION_LOG_LEVEL=quiet
		{
			log_title Heading
			log_step Working
			log_success Done
			log_segments info Part
			log_warning Careful
			log_error Broken
		} 2>&1
	)
	[ "$output" = $'\n Careful\n\n=> Broken' ]
	for level in TITLE STEP SUCCESS WARNING ERROR; do grep -q "\[$level\]" "$FOUNDATION_LOG_FILE"; done
	grep -q '\[STEP\] Part' "$FOUNDATION_LOG_FILE"
}

@test "level quiet in logging.conf is a command's default; FOUNDATION_LOG_LEVEL and -v beat it" {
	use_empty_config
	printf 'logging off\nlevel quiet\n' >"$FOUNDATION_CONFIG_DIR/logging.conf"
	run "${BASH:-bash}" "$cmd" 127.0.0.1
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	FOUNDATION_LOG_LEVEL=normal run "${BASH:-bash}" "$cmd" 127.0.0.1
	[[ $output == *"is online"* ]]
	run "${BASH:-bash}" "$cmd" 127.0.0.1 -v
	[[ $output == *"is online"* ]]
}

@test "directory and error-file of logging.conf place the session and error logs" {
	use_empty_config
	unset FOUNDATION_LOG_DIR
	printf 'directory %s\nerror-file Failures.log\nmaintenance off\n' "$BATS_TEST_TMPDIR/elsewhere" >"$FOUNDATION_CONFIG_DIR/logging.conf"
	run "${BASH:-bash}" "$cmd" --timeout-seconds
	[ "$status" -ne 0 ]
	logs=("$BATS_TEST_TMPDIR/elsewhere"/Session_*_Test-MachineOnline.log)
	[ -f "${logs[0]}" ]
	grep -q '\[ERROR\]' "$BATS_TEST_TMPDIR/elsewhere/Failures.log"
	[ ! -e "$BATS_TEST_TMPDIR/elsewhere/Errors.log" ]
	[ "$(logfile_dir)" = "$BATS_TEST_TMPDIR/elsewhere" ]
	[ "$(logfile_error_file)" = Failures.log ]
}

@test "color lines set the console colours by name or code; an unknown name keeps the default" {
	use_empty_config
	printf 'color title BrightMagenta\ncolor success 38;5;208\ncolor warning nonsense\ncolor step plain\n' >"$FOUNDATION_CONFIG_DIR/logging.conf"
	logfile_load_settings
	unset NO_COLOR
	export LOG_FORCE_COLOR=1 TERM=xterm-256color
	output=$(
		log_title Heading
		log_success Done
		log_warning Careful
		log_step Working
	)
	[[ $output == *$'\033[95m[Heading]'* ]]
	[[ $output == *$'\033[38;5;208m=> Done'* ]]
	[[ $output == *$'\033[33m Careful'* ]]
	[[ $output == *$'\033[0mWorking'* ]]
}
