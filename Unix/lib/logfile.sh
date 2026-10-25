# shellcheck shell=bash
# File logging of the Unix half - the Start-Logging / Write-Log mirror of the Windows Logging
# module. Every log_* line a Foundation command prints is also appended, plain and timestamped, to a
# session log; errors go to the shared error log as well. A session is one top-level command:
# the commands it runs (foundation_run) inherit FOUNDATION_LOG_FILE and write into the same file.
#
#   Unix/logs/Session_<yyyy-MM-dd_HH-mm-ss>_<Command>.log   (gitignored; Pinned/ is never pruned)
#   Unix/logs/Errors.log
#
# Settings and retention: Unix/config/logging.conf (logging on|off, level, directory, error-file,
# color lines, max-age-days, max-session-files, max-total-size-mb, max-error-file-size-mb,
# maintenance, maintenance-interval-hours). FOUNDATION_LOGGING=off turns it off for one run (the test
# suites do), FOUNDATION_LOG_DIR moves the folder for one run. Sourced by foundation.sh after log.sh.
# The settings are read with conf_value / conf_lines of lib/config.sh, so the overlay, @TYPE lines
# and -LINE removals apply as in every other file: when config.sh is not loaded yet (the session log
# starts while foundation.sh loads), it is loaded in a subshell, with stand-ins for the two text
# helpers of foundation.sh it needs, which foundation.sh only defines after this file.

# The text helpers conf_value needs, until foundation.sh defines its own (same behaviour) after
# sourcing this file; a shell that already has them keeps them.
if [ "$(type -t foundation_lower)" != function ]; then
	foundation_lower() {
		printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
	}
fi
if [ "$(type -t foundation_ieq)" != function ]; then
	foundation_ieq() {
		[ "$(foundation_lower "$1")" = "$(foundation_lower "$2")" ]
	}
fi

# A logging.conf value, as conf_value reads it (the last line wins, the overlay after the base,
# @TYPE lines for this machine type only, -LINE removals applied); DEFAULT when no line has KEY or
# its value is empty (a missing key never fails a caller under set -e). Loads lib/config.sh in a
# subshell when it is not loaded yet.
logfile_setting() { # KEY DEFAULT
	local file=${FOUNDATION_CONFIG_DIR:-$FOUNDATION_UNIX/config}/logging.conf value=''
	if [ -r "$file" ]; then
		value=$(
			[ "$(type -t conf_value)" = function ] || . "$FOUNDATION_UNIX/lib/config.sh" || exit 0
			conf_value "$file" "$1"
		) 2>/dev/null || value=''
	fi
	printf '%s' "${value:-$2}"
}

# The SGR code of a `color` value in logfile__code: a List-AvailableColors name (black .. white,
# brightblack .. brightwhite, any case), plain (no colour), or a code itself (36, 38;5;208).
# Fails for anything else, which leaves that style at its default.
logfile__color_code() { # VALUE
	local name base=30
	name=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
	case $name in bright?*)
		base=90
		name=${name#bright}
		;;
	esac
	case $name in
		black) logfile__code=$base ;;
		red) logfile__code=$((base + 1)) ;;
		green) logfile__code=$((base + 2)) ;;
		yellow) logfile__code=$((base + 3)) ;;
		blue) logfile__code=$((base + 4)) ;;
		magenta) logfile__code=$((base + 5)) ;;
		cyan) logfile__code=$((base + 6)) ;;
		white) logfile__code=$((base + 7)) ;;
		plain | none | default) logfile__code=0 ;;
		'' | *[!0-9\;]*) return 1 ;;
		*) logfile__code=$1 ;;
	esac
}

# The settings a command starts with, read in one pass (one subshell, not one per key): logging,
# level, directory, error-file and the `color STYLE COLOR` lines. Sets FOUNDATION_LOG_LEVEL from
# level (quiet or verbose) when the variable is unset, so the environment and -v still win, and the
# LOG_COLOR_* codes log.sh prints with. foundation.sh calls it for every module command, before the
# session opens; bootstrap.sh calls it too. Without a line for any of these keys it reads nothing.
logfile_load_settings() {
	local file=${FOUNDATION_CONFIG_DIR:-$FOUNDATION_UNIX/config}/logging.conf key value level='' keys=level
	logfile__loaded=1
	logfile__logging=on
	logfile__directory=''
	logfile__error_file=''
	[ -n "${FOUNDATION_LOGGING:-}" ] || keys="logging|$keys"
	[ -r "$file" ] || return 0
	grep -qiE "^[[:space:]]*(@[^[:space:]]+[[:space:]]+)?($keys|directory|error-file|color)([[:space:]]|$)" "$file" "${file%.conf}.local.conf" 2>/dev/null || return 0
	while IFS=$'\t' read -r key value; do
		case $key in
			logging) logfile__logging=$value ;;
			level) level=$value ;;
			directory) logfile__directory=$value ;;
			error-file) logfile__error_file=${value##*/} ;;
			color-*)
				logfile__color_code "$value" || continue
				# shellcheck disable=SC2034 # read by log.sh
				case ${key#color-} in
					title) LOG_COLOR_TITLE=$logfile__code ;;
					step) LOG_COLOR_STEP=$logfile__code ;;
					success) LOG_COLOR_SUCCESS=$logfile__code ;;
					warning) LOG_COLOR_WARNING=$logfile__code ;;
					error) LOG_COLOR_ERROR=$logfile__code ;;
					debug) LOG_COLOR_DEBUG=$logfile__code ;;
					info) LOG_COLOR_INFO=$logfile__code ;;
				esac
				;;
		esac
	done < <(
		[ "$(type -t conf_lines)" = function ] || . "$FOUNDATION_UNIX/lib/config.sh" || exit 0
		conf_lines "$file" | awk '{
			key = tolower($1)
			if (key == "color") { key = "color-" tolower($2); value = $3 }
			else { value = $0; sub(/^[^[:space:]]+[[:space:]]*/, "", value) }
			if (key == "logging" || key == "level") value = tolower(value)
			print key "\t" value
		}'
	) 2>/dev/null
	case $level in quiet | verbose) [ -n "${FOUNDATION_LOG_LEVEL:-}" ] || FOUNDATION_LOG_LEVEL=$level ;; esac
	return 0
}

# The log folder: FOUNDATION_LOG_DIR, else the directory line of logging.conf (~ is the home folder,
# a relative path is under the repository), else Unix/logs.
logfile_dir() {
	local dir=${FOUNDATION_LOG_DIR:-}
	if [ -z "$dir" ]; then
		if [ -n "${logfile__loaded:-}" ]; then dir=$logfile__directory; else dir=$(logfile_setting directory ''); fi
	fi
	case $dir in
		'') printf '%s' "$FOUNDATION_UNIX/logs" ;;
		'~') printf '%s' "$HOME" ;;
		\~/*) printf '%s' "$HOME/${dir#\~/}" ;;
		/*) printf '%s' "$dir" ;;
		*) printf '%s' "$DOTFILES_ROOT/$dir" ;;
	esac
}

# The error log's file name in the log folder: the error-file line of logging.conf, else Errors.log.
logfile_error_file() {
	local name
	if [ -n "${logfile__loaded:-}" ]; then name=$logfile__error_file; else name=$(logfile_setting error-file ''); fi
	name=${name##*/}
	printf '%s' "${name:-Errors.log}"
}

logfile__write() { # LEVEL MESSAGE
	[ -n "${FOUNDATION_LOG_FILE:-}" ] || return 0
	local line
	line="$(date +%H:%M:%S) [$1] $2"
	# A file that cannot be written (its folder gone) is skipped silently and never fails the caller:
	# stderr goes first, so the shell's own message for a failed redirect is dropped too.
	printf '%s\n' "$line" 2>/dev/null >>"$FOUNDATION_LOG_FILE" || true
	if [ "$1" = ERROR ]; then
		printf '%s %s (%s)\n' "$(date +%Y-%m-%d)" "$line" "${FOUNDATION_LOG_FILE##*/}" 2>/dev/null >>"$(logfile_dir)/$(logfile_error_file)" || true
	fi
	return 0
}

# Starts a session for COMMAND unless one is already open (a nested command) or logging is off.
logfile_start() { # COMMAND ARGS...
	[ -z "${FOUNDATION_LOG_FILE:-}" ] || return 0
	local dir name logging=on
	if [ -z "${FOUNDATION_LOGGING:-}" ]; then
		if [ -n "${logfile__loaded:-}" ]; then logging=$logfile__logging; else logging=$(logfile_setting logging on); fi
	fi
	[ "${FOUNDATION_LOGGING:-$logging}" = on ] || return 0
	dir=$(logfile_dir)
	mkdir -p "$dir" 2>/dev/null || return 0
	name=$1
	shift
	FOUNDATION_LOG_FILE=$dir/Session_$(date +%Y-%m-%d_%H-%M-%S)_$name.log
	[ -e "$FOUNDATION_LOG_FILE" ] && FOUNDATION_LOG_FILE=${FOUNDATION_LOG_FILE%.log}_$$.log
	export FOUNDATION_LOG_FILE
	printf '# %s %s\n# started %s in %s\n' "$name" "$*" "$(date '+%Y-%m-%d %H:%M:%S')" "$PWD" >"$FOUNDATION_LOG_FILE" 2>/dev/null || {
		unset FOUNDATION_LOG_FILE
		return 0
	}
	# Retention on every new session, in the background so it never slows a command down.
	(logfile__background >/dev/null 2>&1 &)
}

# The background part of a new session: the Clear-OldLogs rules, then the maintenance sweep
# (Invoke-LogMaintenance: backups and test results too) once its interval has passed.
logfile__background() {
	logfile_prune 0
	logfile_maintenance_due || return 0
	FOUNDATION_LOG_FILE='' "${BASH:-bash}" "$FOUNDATION_UNIX/modules/Logging/bin/Invoke-LogMaintenance"
}

# Is the maintenance sweep due? maintenance on (the default) in logging.conf, and the stamp
# <log folder>/.last-maintenance missing or older than maintenance-interval-hours (24; 0 = every
# session). The Logging.Maintenance throttle of Windows.
logfile_maintenance_due() {
	local hours stamp
	foundation_ieq "$(logfile_setting maintenance on)" on || return 1
	hours=$(logfile_setting maintenance-interval-hours 24)
	case $hours in '' | *[!0-9]*) hours=24 ;; esac
	stamp=$(logfile_dir)/.last-maintenance
	[ -f "$stamp" ] || return 0
	[ -z "$(find "$stamp" -mmin -$((10#$hours * 60)) 2>/dev/null)" ]
}

# One file of logfile_prune: removed, or only listed in a dry run. Usage: logfile__drop DRY FILE REASON
logfile__drop() {
	if [ "$1" = 1 ]; then
		printf 'would remove %s (%s)\n' "${2##*/}" "$3"
	else
		rm -f "$2" && printf 'removed %s (%s)\n' "${2##*/}" "$3"
	fi
}

# Clear-OldLogs rules: session logs by age, then count, then total size (oldest first), the
# error log trimmed to its newest part; Pinned/ untouched. DRY-RUN=1 only lists, each file once.
# A limit given (a whole number, 0 = off) overrides logging.conf for this call; empty reads it.
logfile_prune() { # [DRY-RUN] [MAX-AGE-DAYS] [MAX-SESSION-FILES] [MAX-TOTAL-SIZE-MB] [MAX-ERROR-FILE-SIZE-MB]
	local dry=${1:-0} dir age count size cap errors f i kb total gone
	local -a sessions=()
	dir=$(logfile_dir)
	[ -d "$dir" ] || return 0
	age=${2:-$(logfile_setting max-age-days 7)}
	count=${3:-$(logfile_setting max-session-files 20)}
	size=${4:-$(logfile_setting max-total-size-mb 50)}
	cap=${5:-$(logfile_setting max-error-file-size-mb 5)}
	# A file the age step names leaves the list, so the count and size steps never name it again
	# (in a dry run it still exists).
	gone=$'\n'
	if [ "$age" -gt 0 ] 2>/dev/null; then
		while IFS= read -r f; do
			logfile__drop "$dry" "$f" "older than $age days"
			gone+=$f$'\n'
		done < <(find "$dir" -maxdepth 1 -name 'Session_*.log' -type f -mtime +"$age" | LC_ALL=C sort)
	fi
	# The rest, oldest first (the name starts with the session's start time).
	while IFS= read -r f; do
		case $gone in *$'\n'"$f"$'\n'*) continue ;; esac
		sessions+=("$f")
	done < <(find "$dir" -maxdepth 1 -name 'Session_*.log' -type f | LC_ALL=C sort)
	if [ "$count" -gt 0 ] 2>/dev/null && [ ${#sessions[@]} -gt "$count" ]; then
		i=$((${#sessions[@]} - count))
		for f in "${sessions[@]:0:i}"; do logfile__drop "$dry" "$f" "more than $count sessions"; done
		sessions=("${sessions[@]:i}")
	fi
	if [ "$size" -gt 0 ] 2>/dev/null; then
		total=0
		for f in ${sessions[@]+"${sessions[@]}"}; do total=$((total + $(du -k "$f" | cut -f1))); done
		for f in ${sessions[@]+"${sessions[@]}"}; do
			[ "$total" -gt $((size * 1024)) ] || break
			[ "$f" = "${FOUNDATION_LOG_FILE:-}" ] && continue
			kb=$(du -k "$f" | cut -f1)
			logfile__drop "$dry" "$f" "logs over $size MB"
			total=$((total - kb))
		done
	fi
	errors=$(logfile_error_file)
	if [ "$cap" -gt 0 ] 2>/dev/null && [ -f "$dir/$errors" ]; then
		kb=$(du -k "$dir/$errors" | cut -f1)
		if [ "$kb" -gt $((cap * 1024)) ]; then
			# The trim keeps the newest half of the cap, so the file does not hit it again at once.
			if [ "$dry" = 1 ]; then
				printf 'would trim %s to its newest %s KB (half of max-error-file-size-mb %s)\n' "$errors" $((cap * 512)) "$cap"
			else
				tail -c $((cap * 1024 * 1024 / 2)) "$dir/$errors" >"$dir/.$errors.tmp" && mv "$dir/.$errors.tmp" "$dir/$errors" && printf 'trimmed %s to its newest %s KB (half of max-error-file-size-mb %s)\n' "$errors" $((cap * 512)) "$cap"
			fi
		fi
	fi
}

# Mirror the log.sh voice into the session log: each function keeps its terminal behaviour and
# appends its message to the file (a leading -n is a layout flag, not part of the message).
for logfile__fn in log_title log_step log_success log_warning log_error log_debug log_segments; do
	eval "$(declare -f "$logfile__fn" | sed "1s/^$logfile__fn /logfile__tty_$logfile__fn /")"
done
unset logfile__fn
log_title() {
	logfile__tty_log_title "$@"
	[ "${1:-}" = "-n" ] && shift
	logfile__write TITLE "$1"
}
log_step() {
	logfile__tty_log_step "$@"
	[ "${1:-}" = "-n" ] && shift
	logfile__write STEP "$1"
}
log_success() {
	logfile__tty_log_success "$@"
	[ "${1:-}" = "-n" ] && shift
	logfile__write SUCCESS "$1"
}
log_warning() {
	logfile__tty_log_warning "$@"
	[ "${1:-}" = "-n" ] && shift
	logfile__write WARNING "$1"
}
log_error() {
	logfile__tty_log_error "$@"
	[ "${1:-}" = "-n" ] && shift
	logfile__write ERROR "$1"
}
log_segments() {
	logfile__tty_log_segments "$@"
	[ "${1:-}" = "-n" ] && shift
	local text=''
	while [ $# -ge 2 ]; do
		text+=$2
		shift 2
	done
	logfile__write STEP "$text"
}
log_debug() {
	logfile__tty_log_debug "$@"
	[ "${1:-}" = "-n" ] && shift
	logfile__write DEBUG "$1"
}
