# shellcheck shell=sh
# Shared logging helpers for the Unix side of the repository.
#
# Unix counterpart of WinuX's Logging module (Windows/PowerShell/Modules/Logging). The visual language is
# identical so output reads the same on Windows, macOS and Linux:
#
#   log_title    <-> Write-LogTitle     cyan, bracketed
#   log_step     <-> Write-LogStep      plain, the message as given (its own leading spaces kept)
#   log_success  <-> Write-LogSuccess   green,  "=> " prefix
#   log_warning  <-> Write-LogWarning   yellow, " " prefix
#   log_error    <-> Write-LogError     red,    "=> " prefix, written to stderr
#   log_segments <-> Write-LogSegments  one line of differently colored parts
#
# Every line starts with a blank line, like Write-Log. A first argument of -n drops it (the
# -NoLeadingNewline of Windows) - for a compact run of lines such as a list under a step.
#
# Strict POSIX sh: no bashisms, no zsh-isms, no reserved-name collisions. Source
# this file, never execute it.
#
# Colour is emitted only when the target stream is a terminal, so piping into a
# file or capturing from cron produces clean, unescaped text everywhere.
#
# The colours are SGR codes in LOG_COLOR_TITLE, _STEP, _SUCCESS, _WARNING, _ERROR, _DEBUG and _INFO
# (the Logging.Colors of Windows), set by lib/logfile.sh from the `color` lines of logging.conf;
# unset, each keeps the code above (step plain, debug 90).
#
# FOUNDATION_LOG_LEVEL=quiet (Set-LogLevel Quiet) prints only warnings and errors: title, step,
# success and segments print nothing (the session log of lib/logfile.sh still gets them).

# Usage: log_use_color <fd>   where <fd> is 1 (stdout) or 2 (stderr)
# LOG_FORCE_COLOR=1 colors output held in a file that is shown on the terminal later.
log_use_color() {
	[ -z "${NO_COLOR:-}" ] || return 1
	[ "${TERM:-dumb}" != "dumb" ] || return 1
	[ "${LOG_FORCE_COLOR:-}" != "1" ] || return 0

	if [ "${1:-1}" = "2" ]; then
		[ -t 2 ]
	else
		[ -t 1 ]
	fi
}

# Is the console level quiet? Usage: log__quiet && return 0
log__quiet() {
	[ "${FOUNDATION_LOG_LEVEL:-}" = quiet ]
}

# The leading blank line, unless the first argument is -n. Usage: log__lead "$@"
log__lead() {
	[ "${1:-}" = "-n" ] || printf '\n'
}

# Prints LEAD-ARGS... as one line in ANSI COLOR when FD is a terminal. Usage: log__line FD COLOR TEXT
log__line() {
	if [ -n "$2" ] && log_use_color "$1"; then
		printf '\033[%sm%s\033[0m\n' "$2" "$3"
	else
		printf '%s\n' "$3"
	fi
}

log_title() {
	log__quiet && return 0
	log__lead "$@"
	[ "${1:-}" = "-n" ] && shift
	log__line 1 "${LOG_COLOR_TITLE:-36}" "[$1]"
}

log_step() {
	log__quiet && return 0
	log__lead "$@"
	[ "${1:-}" = "-n" ] && shift
	log__line 1 "${LOG_COLOR_STEP:-}" "$1"
}

log_success() {
	log__quiet && return 0
	log__lead "$@"
	[ "${1:-}" = "-n" ] && shift
	log__line 1 "${LOG_COLOR_SUCCESS:-32}" "=> $1"
}

log_warning() {
	log__lead "$@"
	[ "${1:-}" = "-n" ] && shift
	log__line 1 "${LOG_COLOR_WARNING:-33}" " $1"
}

log_error() {
	log__lead "$@" >&2
	[ "${1:-}" = "-n" ] && shift
	log__line 2 "${LOG_COLOR_ERROR:-31}" "=> $1" >&2
}

# One line of parts, each in its own color, like Write-LogSegments: STYLE TEXT pairs, STYLE one of
# title, step, success, warning, error, info (blue) or empty for plain.
# Usage: log_segments [-n] STYLE TEXT [STYLE TEXT]...
log_segments() {
	log__quiet && return 0
	log__lead "$@"
	[ "${1:-}" = "-n" ] && shift
	log__segments_color=0
	log_use_color 1 && log__segments_color=1
	while [ $# -ge 2 ]; do
		case $1 in
			title) log__segments_code=${LOG_COLOR_TITLE:-36} ;;
			success) log__segments_code=${LOG_COLOR_SUCCESS:-32} ;;
			warning) log__segments_code=${LOG_COLOR_WARNING:-33} ;;
			error) log__segments_code=${LOG_COLOR_ERROR:-31} ;;
			info) log__segments_code=${LOG_COLOR_INFO:-34} ;;
			*) log__segments_code=${LOG_COLOR_STEP:-} ;;
		esac
		if [ "$log__segments_color" -eq 1 ] && [ -n "$log__segments_code" ]; then
			printf '\033[%sm%s\033[0m' "$log__segments_code" "$2"
		else
			printf '%s' "$2"
		fi
		shift 2
	done
	printf '\n'
}
