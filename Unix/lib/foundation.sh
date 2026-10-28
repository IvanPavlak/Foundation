# shellcheck shell=bash
# Core library of Foundation, the Unix half. Sourced by every executable in Unix/modules/<Module>/bin, never run.
#
# What it gives a command:
#   - DOTFILES_ROOT, FOUNDATION_UNIX, FOUNDATION_CONFIG_DIR, FOUNDATION_STATE_DIR resolved from its own location
#   - the logging voice of Unix/lib/log.sh plus log_debug (FOUNDATION_LOG_LEVEL=verbose, or -v/--verbose;
#     quiet prints only warnings and errors; the level line of logging.conf is the default)
#   - foundation_require_bash: the bash 4.4 gate every executable passes before doing work
#   - foundation_normalize_args: accept the Windows spelling of a flag (-TimeoutSeconds 45) next to the
#     Unix one (--timeout-seconds 45), so muscle memory from WinuX works unchanged
#   - foundation_match_*: the pattern rules of the Windows Get-WindowHandle / Test-WindowTitleMatch
#   - foundation_title_has_segment: the whole-segment rule of the Windows Test-WindowTitleCandidates
#   - foundation_usage: prints the man-style header comment of the calling executable
#
# Written to run under bash 3.2 as well (no associative arrays, no mapfile, no ${x,,}) so the
# pure helpers stay testable on a stock macOS; the version gate is a policy decision, not a
# technical need of this file. See docs/foundation/README.md.

# Guard against double sourcing.
if [ -n "${FOUNDATION_LIB_LOADED:-}" ]; then
	return 0
fi
FOUNDATION_LIB_LOADED=1

# ---------------------------------------------------------------------------------------------
# Locations
# ---------------------------------------------------------------------------------------------

# Resolve Unix/ from this file's own path (through symlinks), so nothing depends on where the
# repository is cloned. BASH_SOURCE[0] is this library.
foundation__self=${BASH_SOURCE[0]}
while [ -L "$foundation__self" ]; do
	foundation__target=$(readlink "$foundation__self")
	case $foundation__target in
		/*) foundation__self=$foundation__target ;;
		*) foundation__self=$(dirname "$foundation__self")/$foundation__target ;;
	esac
done
FOUNDATION_UNIX=$(CDPATH='' cd -- "$(dirname -- "$foundation__self")/.." && pwd -P)
unset foundation__self foundation__target

DOTFILES_ROOT=${DOTFILES_ROOT:-$(dirname "$FOUNDATION_UNIX")}
FOUNDATION_CONFIG_DIR=${FOUNDATION_CONFIG_DIR:-$FOUNDATION_UNIX/config}
FOUNDATION_STATE_DIR=${FOUNDATION_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/foundation}
export DOTFILES_ROOT FOUNDATION_UNIX FOUNDATION_CONFIG_DIR FOUNDATION_STATE_DIR

# Homebrew's prefix is missing from PATH when a command is started from a GUI context
# (AeroSpace exec-and-forget, Finder), which would hide aerospace, wezterm and jq.
# FOUNDATION_NO_BREW_PATH=1 leaves PATH as it is: the test seam behind hide_tool
# (tests/helpers.bash), so a "not installed" case cannot reach the real brew, mas, conda or dotnet.
if [ "${FOUNDATION_NO_BREW_PATH:-}" != 1 ]; then
	for foundation__brew in /opt/homebrew/bin /usr/local/bin; do
		case ":$PATH:" in
			*":$foundation__brew:"*) ;;
			*) [ -d "$foundation__brew" ] && PATH="$PATH:$foundation__brew" ;;
		esac
	done
fi
unset foundation__brew
# Every module's bin, the Import-Module analog: a module is a folder of Unix/modules with a
# module.conf manifest and a bin of commands. The fork-only modules of the Custom area
# (Unix/modules/Custom/<Module>) go on PATH first, so the engine's are prepended before them and
# an engine command wins over a Custom one of the same name, as on Windows.
for foundation__bin in "$FOUNDATION_UNIX"/modules/Custom/*/bin "$FOUNDATION_UNIX"/modules/*/bin; do
	case ":$PATH:" in
		*":$foundation__bin:"*) ;;
		*) [ -d "$foundation__bin" ] && PATH="$foundation__bin:$PATH" ;;
	esac
done
unset foundation__bin
export PATH

# Run-Tests --build-impact-map (the -BuildImpactMap of Windows): while FOUNDATION_IMPACT_LOG is
# set, every Foundation command that starts records itself for the suite running it
# (FOUNDATION_IMPACT_SUITE), and foundation_load records each library, as SUITE<TAB>KIND<TAB>NAME.
# Recorded here and not through a PATH shim, since the suites start commands by path and
# foundation_run resolves them in Unix/modules directly.
if [ -n "${FOUNDATION_IMPACT_LOG:-}" ]; then
	case $0 in
		*/modules/*/bin/*) printf '%s\tcommand\t%s\n' "${FOUNDATION_IMPACT_SUITE:-}" "${0##*/}" >>"$FOUNDATION_IMPACT_LOG" 2>/dev/null ;;
	esac
fi

# shellcheck source=log.sh
. "$FOUNDATION_UNIX/lib/log.sh"

# Source further libraries by name: foundation_load config apps drivers/aerospace
foundation_load() {
	local name
	for name in "$@"; do
		[ -z "${FOUNDATION_IMPACT_LOG:-}" ] || printf '%s\tlib\t%s\n' "${FOUNDATION_IMPACT_SUITE:-}" "$name" >>"$FOUNDATION_IMPACT_LOG" 2>/dev/null
		# shellcheck source=/dev/null
		. "$FOUNDATION_UNIX/lib/$name.sh" || return 1
	done
}

# The module folders, one per line: every engine module (Unix/modules/<Module>), then every
# fork-only module of the Custom area (Unix/modules/Custom/<Module>, Modules/Custom on Windows).
# Custom itself is the area, not a module.
foundation_module_dirs() {
	local dir
	for dir in "$FOUNDATION_UNIX"/modules/*/ "$FOUNDATION_UNIX"/modules/Custom/*/; do
		[ -d "$dir" ] || continue
		dir=${dir%/}
		[ "$dir" = "$FOUNDATION_UNIX/modules/Custom" ] && continue
		printf '%s\n' "$dir"
	done
}

# The name of the module in folder DIR: Workflow, or Custom/Workflow in the Custom area. It is also
# the folder of the module's suites under tests/modules.
foundation_module_name() { # DIR
	local dir=${1%/}
	case $dir in
		*/modules/Custom/*) printf 'Custom/%s\n' "${dir##*/}" ;;
		*) printf '%s\n' "${dir##*/}" ;;
	esac
}

# The page of module NAME (foundation_module_name), relative to the repository root:
# docs/foundation/modules/<Module>.md, or docs/foundation/custom/<module>.md (lowercase, as docs/custom on
# Windows) for a Custom module.
foundation_module_page() { # NAME
	case $1 in
		Custom/*) printf 'docs/foundation/custom/%s.md\n' "$(foundation_lower "${1#Custom/}")" ;;
		*) printf 'docs/foundation/modules/%s.md\n' "$1" ;;
	esac
}

# Path of the Foundation command NAME, in whichever module holds it; an engine command wins over a
# Custom one. (Checked as a file, not -x, so a checkout that lost the executable bit still works.)
foundation_command_path() {
	local file
	[ -n "$1" ] || return 1
	for file in "$FOUNDATION_UNIX"/modules/*/bin/"$1" "$FOUNDATION_UNIX"/modules/Custom/*/bin/"$1"; do
		[ -f "$file" ] && {
			printf '%s\n' "$file"
			return 0
		}
	done
	return 1
}

# Is NAME a Foundation command?
foundation_has_command() {
	foundation_command_path "$1" >/dev/null
}

# Every command as MODULE<TAB>NAME (MODULE as foundation_module_name prints it), sorted by module then
# name, the engine modules first.
foundation_commands() {
	local dir file module
	while IFS= read -r dir; do
		module=$(foundation_module_name "$dir")
		for file in "$dir"/bin/*; do
			[ -f "$file" ] || continue
			printf '%s\t%s\n' "$module" "${file##*/}"
		done
	done < <(foundation_module_dirs)
}

# Runs an application (or anything that outlives this command) without Foundation's own environment.
# Apps inherit the environment of whoever starts them: an app started by `w` would otherwise keep
# FOUNDATION_LOG_FILE, FOUNDATION_WORKSPACE_OPEN, FOUNDATION_RUN_DIR, ... of that open, and every Foundation command
# run later from it (a VS Code or Claude terminal) would log into that finished session and act
# as if a workspace open were in progress. Usage: foundation_launch PROGRAM [ARGS...]
foundation_launch() {
	local unset=() name
	while IFS='=' read -r name _; do
		case $name in FOUNDATION_*) unset+=(-u "$name") ;; esac
	done < <(env)
	env ${unset[@]+"${unset[@]}"} "$@"
}

# Runs COMMAND with a time limit, as GNU timeout does (macOS has none): a COMMAND still running
# after SECONDS is sent TERM and the status is 124; otherwise COMMAND's own status. The watcher
# holds no output of the caller, so `out=$(foundation_timeout ...)` returns at once when COMMAND
# ends. Usage: foundation_timeout SECONDS COMMAND [ARGS...]
foundation_timeout() {
	local seconds=$1 pid watcher status
	shift
	"$@" &
	pid=$!
	(
		trap 'kill "$sleeper" 2>/dev/null; exit 0' TERM
		sleep "$seconds" &
		sleeper=$!
		wait "$sleeper"
		kill -TERM "$pid" 2>/dev/null
	) </dev/null >/dev/null 2>&1 &
	watcher=$!
	wait "$pid"
	status=$?
	kill -TERM "$watcher" 2>/dev/null
	wait "$watcher" 2>/dev/null
	[ "$status" -eq 143 ] && status=124
	return "$status"
}

# Run another Foundation command in a fresh process under the same bash.
foundation_run() {
	local name=$1 path
	shift
	path=$(foundation_command_path "$name") || {
		log_error "Unknown Foundation command => $name"
		return 127
	}
	"${BASH:-bash}" "$path" "$@"
}

# Register-DeferredAction: queues the slow tail of an action (Obsidian's workspace load after a
# cold start) so the actions after it do not wait for it; Open-Workspace runs the queue with
# foundation_flush_deferred just before its layout, by which time the tail is usually instant.
# Generic: any opener may use it. COMMAND is a Foundation command (run through foundation_run).
# Without a run directory (the command started on its own) it runs at once, as on Windows.
# Usage: foundation_defer LABEL COMMAND [ARGUMENT...]
foundation_defer() {
	local label=$1 line
	shift
	if [ -n "${FOUNDATION_RUN_DIR:-}" ] && [ -d "$FOUNDATION_RUN_DIR" ]; then
		line=$(printf ' %q' "$@")
		printf '%s\t%s\n' "$label" "${line# }" >>"$FOUNDATION_RUN_DIR/deferred-actions"
		log_debug "[foundation_defer] queued [$label]"
		return 0
	fi
	foundation_run "$@"
}

# Complete-DeferredActions: runs every queued action in order and empties the queue (an action
# queued while it runs waits for the next flush). Exit status 1 when one failed; each failure is
# a warning naming its label. Usage: foundation_flush_deferred
foundation_flush_deferred() {
	local file=${FOUNDATION_RUN_DIR:-}/deferred-actions queue label line status=0
	local -a words
	[ -n "${FOUNDATION_RUN_DIR:-}" ] && [ -s "$file" ] || return 0
	queue=$file.running
	mv "$file" "$queue" || return 0
	while IFS=$'\t' read -r label line; do
		[ -n "$line" ] || continue
		eval "words=($line)"
		log_debug "[foundation_flush_deferred] running [$label]"
		foundation_run "${words[@]}" </dev/null || {
			log_warning "Deferred action [$label] failed"
			status=1
		}
	done <"$queue"
	rm -f "$queue"
	return $status
}

# ---------------------------------------------------------------------------------------------
# Logging additions
# ---------------------------------------------------------------------------------------------

# Write-LogDebug analog: only printed at the verbose level, dimmed, on stderr so it never mixes
# into a command's data output.
log_debug() {
	case ${FOUNDATION_LOG_LEVEL:-normal} in
		verbose | debug) ;;
		*) return 0 ;;
	esac
	if log_use_color 2; then
		printf '\033[%sm  [debug] %s\033[0m\n' "${LOG_COLOR_DEBUG:-90}" "$1" >&2
	else
		printf '  [debug] %s\n' "$1" >&2
	fi
}

# Fatal error: log and exit with the given status (default 1).
foundation_die() {
	log_error "$1"
	exit "${2:-1}"
}

# File logging (lib/logfile.sh): the log_* functions above also write the session log. A session
# opens only for a module command (Unix/modules/*/bin/*), after logging.conf's level, colours and
# folder are read; a library sourced by the tests or a background snippet writes nothing.
# shellcheck source=logfile.sh
. "$FOUNDATION_UNIX/lib/logfile.sh"
case $0 in *modules/*/bin/*)
	logfile_load_settings
	logfile_start "${0##*/}" "$@"
	;;
esac

# ---------------------------------------------------------------------------------------------
# Version gate
# ---------------------------------------------------------------------------------------------

# Every executable calls this first. Standing decision: executables need bash 4.4+, which macOS
# does not ship (it froze at 3.2.57), so Homebrew bash is installed by the first bootstrap step.
# FOUNDATION_ALLOW_OLD_BASH=1 lets the test suite run the pure helpers on a stock bash; it is not
# meant for day-to-day use.
foundation_require_bash() {
	if [ "${BASH_VERSINFO[0]:-0}" -gt 4 ] ||
		{ [ "${BASH_VERSINFO[0]:-0}" -eq 4 ] && [ "${BASH_VERSINFO[1]:-0}" -ge 4 ]; }; then
		return 0
	fi
	[ "${FOUNDATION_ALLOW_OLD_BASH:-0}" = "1" ] && return 0
	log_error "bash ${BASH_VERSION%%(*} is too old for Foundation (needs 4.4+). Install it with => brew install bash"
	log_step "Then open a new terminal so /opt/homebrew/bin comes before /bin on PATH."
	return 1
}

# ---------------------------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------------------------

# Convert a Windows-style parameter name to its Unix spelling:
#   -TimeoutSeconds -> --timeout-seconds, -Skip -> --skip, -v stays -v, --x stays --x.
foundation_flag_name() {
	case $1 in
		--*) printf '%s' "$1" ;;
		-[A-Z]*)
			printf -- '-%s' "$(printf '%s' "${1#-}" | sed -e 's/\([A-Z]\)/-\1/g' | tr '[:upper:]' '[:lower:]')"
			;;
		*) printf '%s' "$1" ;;
	esac
}

# The long flags a command documents in its header (--include-current ...), one per line.
# Usage: foundation_command_flags SCRIPT
foundation_command_flags() {
	foundation_usage "$1" | grep -oE -- '--[a-z][a-z0-9-]*' | sort -u
}

# A flag with every dash removed and lowercased: the case- and dash-insensitive key PowerShell
# parameter binding effectively uses (-IncludeCurrent, -includecurrent, --include-current).
foundation__flag_key() {
	printf '%s' "$1" | tr -d '-' | tr '[:upper:]' '[:lower:]'
}

# Rewrites "$@" into the global array FOUNDATION_ARGS with every Windows-style flag converted. A
# flag that matches one of the calling command's documented flags case- and dash-insensitively
# becomes that flag, so `kill-all -includecurrent` works like PowerShell; anything else gets the
# CamelCase conversion of foundation_flag_name. The PowerShell switches a command does not
# document never reach it as a value: -WhatIf becomes --dry-run where the header documents one and
# stops the command elsewhere (as on Windows, where only a few functions take it); -Confirm,
# -Debug and -ErrorAction stop it too. A PowerShell-style flag (one dash) that matches no flag
# whole may be an abbreviation, as the Windows binder allows: the one documented flag whose key
# starts with it is taken (-Along => --alongside), and a prefix several flags share stops the
# command as ambiguous; a single letter (-v, -h) is a short option and never abbreviates.
# Nothing has run at that point.
# Usage: foundation_normalize_args "$@"; set -- "${FOUNDATION_ARGS[@]}"
foundation_normalize_args() {
	FOUNDATION_ARGS=()
	local known argument key flag converted
	known=$(foundation_command_flags "$0" 2>/dev/null)
	for argument in "$@"; do
		converted=''
		case $argument in
			-?*)
				key=$(foundation__flag_key "$argument")
				for flag in $known; do
					if [ "$(foundation__flag_key "$flag")" = "$key" ]; then
						converted=$flag
						break
					fi
				done
				# -WhatIf:$true, -Confirm:$false: the switch is the part before the colon.
				[ -n "$converted" ] || case ${key%%:*} in
					whatif)
						case " $(printf '%s ' $known)" in
							*" --dry-run "*) converted=--dry-run ;;
							*) foundation_die "${0##*/} has no dry run ($argument) - nothing was done" ;;
						esac
						;;
					confirm | debug | erroraction)
						foundation_die "${0##*/} does not take $argument - nothing was done"
						;;
				esac
				# A PowerShell abbreviation (-Along for -Alongside): the one documented flag whose
				# key starts with this one; several are an error, as the Windows binder says. Two
				# characters at least: a single letter (-v, -h, -d) is a short option, never an
				# abbreviation.
				case $argument in
					-[!-]?*)
						[ -n "$converted" ] || case $key in
							*:*) ;;
							*)
								local matches=()
								for flag in $known; do
									case $(foundation__flag_key "$flag") in "$key"*) matches+=("$flag") ;; esac
								done
								if [ ${#matches[@]} -eq 1 ]; then
									converted=${matches[0]}
								elif [ ${#matches[@]} -gt 1 ]; then
									foundation_die "${0##*/}: $argument is ambiguous (${matches[*]}) - nothing was done"
								fi
								;;
						esac
						;;
				esac
				;;
		esac
		[ -n "$converted" ] || converted=$(foundation_flag_name "$argument")
		FOUNDATION_ARGS+=("$converted")
	done
}

# Appends the comma-separated names in VALUE to the array named LIST, so `cw Server,Client` works
# as `cw Server, Client` does in PowerShell: blanks around a name and empty items (the trailing
# comma of `A, B` arriving as `A,` `B`) are dropped. Usage: foundation_split_list LIST VALUE
foundation_split_list() {
	# The locals carry a prefix: eval appends to the caller's array by name, and a local of the
	# same name (names, list) would shadow it.
	local _fsl_list=$1 _fsl_item _fsl_items
	IFS=, read -r -a _fsl_items <<<"$2"
	for _fsl_item in ${_fsl_items[@]+"${_fsl_items[@]}"}; do
		_fsl_item=$(foundation_trim "$_fsl_item")
		[ -n "$_fsl_item" ] || continue
		eval "$_fsl_list+=(\"\$_fsl_item\")"
	done
}

# Prints the man-style header of the calling executable: every comment line after the shebang
# up to the first non-comment line, with the leading "# " removed. The same block is what the
# docs pages reproduce, so `<Command> --help` and the docs never disagree.
foundation_usage() {
	local script=${1:-$0}
	awk 'NR == 1 && /^#!/ { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$script"
}

# Standard handling of -h/--help and -v/--verbose for executables; call it with "$@" before
# parsing. Sets FOUNDATION_LOG_LEVEL when verbose is asked for.
foundation_common_flags() {
	local argument
	for argument in "$@"; do
		case $argument in
			-h | --help)
				foundation_usage "$0"
				exit 0
				;;
			-v | --verbose) FOUNDATION_LOG_LEVEL=verbose ;;
		esac
	done
	export FOUNDATION_LOG_LEVEL
}

# ---------------------------------------------------------------------------------------------
# Text helpers
# ---------------------------------------------------------------------------------------------

foundation_lower() {
	printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

# Is VALUE a whole number from MIN to MAX (the ValidateRange of Windows)?
# Usage: foundation_whole_number VALUE MIN MAX
foundation_whole_number() {
	case $1 in '' | *[!0-9]*) return 1 ;; esac
	[ ${#1} -le 9 ] && [ "$((10#$1))" -ge "$2" ] && [ "$((10#$1))" -le "$3" ]
}

foundation_trim() {
	local value=$1
	value=${value#"${value%%[![:space:]]*}"}
	value=${value%"${value##*[![:space:]]}"}
	printf '%s' "$value"
}

# Case-insensitive string equality (PowerShell -eq semantics). Without a process: the step
# resolvers compare every catalog step with every config line, and two `tr` runs per comparison
# cost Bootstrap seconds per start. nocasematch is restored to what the caller had.
foundation_ieq() {
	local result=0
	if shopt -q nocasematch; then
		[[ $1 == "$2" ]] || result=1
	else
		shopt -s nocasematch
		[[ $1 == "$2" ]] || result=1
		shopt -u nocasematch
	fi
	return $result
}

# Expand ~ and $VARIABLES in a configured path without eval. DEFAULT means $HOME. $DEV (or ${DEV})
# is the dev root, the {Dev} of Windows (foundation_dev_root of lib/config.sh, else the folder
# holding this clone), whatever DEV the environment holds; it is resolved once per process.
foundation_expand_path() {
	local path=$1
	case $path in
		DEFAULT)
			printf '%s' "$HOME"
			return 0
			;;
		'~') path=$HOME ;;
		\~/*) path=$HOME/${path#\~/} ;;
	esac
	# ${NAME} and $NAME, one pass, unknown variables expand to empty like the shell would.
	while [[ $path =~ \$\{?([A-Za-z_][A-Za-z0-9_]*)\}? ]]; do
		local name=${BASH_REMATCH[1]}
		local whole=${BASH_REMATCH[0]}
		if [ "$name" = DEV ]; then
			if [ -z "${foundation__dev_root:-}" ]; then
				if declare -F foundation_dev_root >/dev/null; then
					foundation__dev_root=$(foundation_dev_root)
				else
					foundation__dev_root=$(dirname "$DOTFILES_ROOT")
				fi
			fi
			path=${path/"$whole"/$foundation__dev_root}
			continue
		fi
		path=${path/"$whole"/${!name:-}}
	done
	printf '%s' "$path"
}

# Milliseconds since the epoch where the platform can say so, seconds * 1000 otherwise. Used
# for timeouts only, so the coarse fallback is harmless.
foundation_now_ms() {
	if [ -n "${EPOCHREALTIME:-}" ]; then
		local now=${EPOCHREALTIME/./}
		printf '%s' "${now:0:13}"
	else
		printf '%s000' "$(date +%s)"
	fi
}

# ---------------------------------------------------------------------------------------------
# Pattern matching - Windows semantics
# ---------------------------------------------------------------------------------------------
#
# Layout files, Kill-All -Exclude and the app lookups carry the patterns the Windows side uses.
# Two rule sets exist there, and both are reproduced:
#
#   process patterns (Get-WindowHandle -ProcessName): the EXACT name always matches (notepad++);
#     otherwise a value with only * and ? is a wildcard and anything else a regex.
#   title patterns (Test-WindowTitleMatch): a value is tried as a REGEX first (so a plain word is a
#     substring match); only a value .NET rejects as a regex but that looks like a wildcard is
#     treated as one. The only such values in practice start with "*" ("*YouTube*"). A value POSIX
#     ERE rejects (notepad++) is matched literally, as a substring.
#
# Matching is case-insensitive, like PowerShell's -match and -like. .NET shorthand classes that
# POSIX ERE lacks (\s \d \w) are translated before matching, and a leading (?i) is dropped.

foundation__has_regex_meta() {
	case $1 in
		*[.\[\]\(\)\{\}+^\$\|\\]*) return 0 ;;
	esac
	return 1
}

foundation__has_wildcard() {
	case $1 in
		*[\*\?]*) return 0 ;;
	esac
	return 1
}

foundation__to_ere() {
	local re=$1
	# .NET's inline case-insensitive flag, which ERE rejects; matching is case-insensitive anyway.
	re=${re#'(?i)'}
	re=${re//\\s/[[:space:]]}
	re=${re//\\S/[^[:space:]]}
	re=${re//\\d/[0-9]}
	re=${re//\\w/[[:alnum:]_]}
	printf '%s' "$re"
}

# Case-insensitive glob and regex tests that restore the caller's nocasematch setting.
foundation__glob_match() {
	local text=$1 pattern=$2 status=1 restore=0
	shopt -q nocasematch || {
		shopt -s nocasematch
		restore=1
	}
	# shellcheck disable=SC2053 # the right-hand side is a glob on purpose
	[[ $text == $pattern ]] && status=0
	[ "$restore" -eq 1 ] && shopt -u nocasematch
	return $status
}

# Status 0 on a match, 1 on none, 2 when ERE rejects the pattern (notepad++, a .NET construct
# ERE lacks); bash's own complaint about it is kept off the terminal.
foundation__regex_match() {
	local text=$1 pattern status restore=0
	pattern=$(foundation__to_ere "$2")
	shopt -q nocasematch || {
		shopt -s nocasematch
		restore=1
	}
	[[ $text =~ $pattern ]] 2>/dev/null
	status=$?
	[ "$restore" -eq 1 ] && shopt -u nocasematch
	return $status
}

# A title pattern ERE rejects is taken literally: a case-insensitive substring of the title.
foundation__title_regex_match() { # TITLE PATTERN
	local status literal=${2#'(?i)'} restore=0
	foundation__regex_match "$1" "$2"
	status=$?
	[ $status -eq 2 ] || return $status
	shopt -q nocasematch || {
		shopt -s nocasematch
		restore=1
	}
	status=1
	[[ $1 == *"$literal"* ]] && status=0
	[ "$restore" -eq 1 ] && shopt -u nocasematch
	return $status
}

# Usage: foundation_match_process PATTERN NAME
foundation_match_process() {
	local pattern=$1 name=$2
	[ -n "$pattern" ] || return 1
	# An exact name always matches, metacharacters or not: process names may hold them
	# (notepad++), and Windows falls back to the exact name when the pattern is no valid regex.
	foundation_ieq "$pattern" "$name" && return 0
	if ! foundation__has_regex_meta "$pattern" && ! foundation__has_wildcard "$pattern"; then
		return 1
	fi
	if foundation__has_wildcard "$pattern" && ! foundation__has_regex_meta "$pattern"; then
		foundation__glob_match "$name" "$pattern"
		return
	fi
	foundation__regex_match "$name" "$pattern" && return 0
	return 1
}

# Usage: foundation_match_title PATTERN TITLE   (an empty pattern matches every title)
foundation_match_title() {
	local pattern=$1 title=$2
	[ -n "$pattern" ] || return 0
	[ "$pattern" = '$null' ] && return 0
	[ -n "$title" ] || return 1
	# .NET rejects a leading quantifier; those values are the wildcard ones.
	case $pattern in
		'*'* | '?'*)
			if ! foundation__has_regex_meta "$pattern"; then
				foundation__glob_match "$title" "$pattern"
				return
			fi
			# "*x.y*": wildcard with a literal dot - escape the metas and glob it.
			foundation__glob_match "$title" "$pattern"
			return
			;;
	esac
	if foundation__has_wildcard "$pattern" && ! foundation__has_regex_meta "$pattern"; then
		# "foo*bar": valid .NET regex (o* = zero or more o), matched as one.
		foundation__title_regex_match "$title" "$pattern"
		return
	fi
	foundation__title_regex_match "$title" "$pattern"
}

# Test-WindowTitleMatch with a process: a pattern equal to the process name also matches.
# Usage: foundation_match_any PROCESS TITLE PATTERN...
foundation_match_any() {
	local process=$1 title=$2 pattern
	shift 2
	for pattern in "$@"; do
		[ -n "$pattern" ] || continue
		if [ -n "$process" ] && foundation_ieq "$pattern" "$process"; then
			return 0
		fi
		[ -n "$title" ] || continue
		foundation_match_title "$pattern" "$title" && return 0
	done
	return 1
}

# Test-WindowTitleCandidates analog: does any CANDIDATE fill a whole segment of TITLE? Segments are
# separated by " - " or by " <em-dash> ", VS Code's default separator on macOS; the candidate is
# compared case-insensitively and literally, so "MyApp" matches "main.ts <em-dash> MyApp" but not
# "main.ts <em-dash> myapp-ui", and a folder "MyApp" does not match a "MyApp (Workspace)" window.
# A leading dirty marker (U+25CF and a space) is ignored and blank candidates are skipped.
# Both characters are built from bytes so this file stays ASCII.
printf -v FOUNDATION__EM_DASH '\342\200\224'
printf -v FOUNDATION__DIRTY_MARK '\342\227\217'
# Usage: foundation_title_has_segment TITLE CANDIDATE...
foundation_title_has_segment() {
	local title=$1 candidate result=1 restore=0
	shift
	title=${title#"$FOUNDATION__DIRTY_MARK "}
	title=" - ${title//" $FOUNDATION__EM_DASH "/ - } - "
	shopt -q nocasematch || {
		shopt -s nocasematch
		restore=1
	}
	for candidate in "$@"; do
		[[ $candidate == *[![:space:]]* ]] || continue
		candidate=${candidate//" $FOUNDATION__EM_DASH "/ - }
		if [[ $title == *" - $candidate - "* ]]; then
			result=0
			break
		fi
	done
	[ "$restore" -eq 1 ] && shopt -u nocasematch
	return $result
}

# ---------------------------------------------------------------------------------------------
# Interactive selection (Resolve-Selection analog)
# ---------------------------------------------------------------------------------------------

# Port of Resolve-Selection, the one menu every command uses:
#
#    [Available workspaces]
#
#    [1] Example
#    [2] Dotfiles
#
#   Enter workspace(s) or press [Enter] to open default workspace (default: Example):
#
# An answer is one or more numbers or names (case-insensitive), separated by spaces or commas;
# each option is printed once, in the order given. Any invalid item re-prompts with the offending
# entries listed, as on Windows. An empty answer prints the default when there is one
# (FOUNDATION_SELECTION_DEFAULT, an option's number or name, set for one call:
# `FOUNDATION_SELECTION_DEFAULT=2 foundation_resolve_selection ...`, the -DefaultOptionIndex of
# Windows, shown as "(default: NAME)" in the prompt), else prints nothing and succeeds when
# ALLOW-EMPTY is 1 (the caller then applies its own default) and re-prompts otherwise. With MULTI 0
# only one item may be given. The menu is drawn on stderr and read from the terminal, so the
# chosen names are the only thing on stdout. FOUNDATION_TTY replaces /dev/tty as the terminal every
# Foundation prompt reads; the test suites point it at a missing file, so a prompt fails as it
# does without a terminal instead of waiting for keyboard input.
# Usage: foundation_resolve_selection TITLE PROMPT ALLOW-EMPTY MULTI OPTION...
foundation_resolve_selection() {
	local title=$1 prompt=$2 allow_empty=$3 multi=$4
	shift 4
	[ $# -gt 0 ] || return 1
	foundation__flat_options "$@"
	foundation__select "$title" "$prompt" "$allow_empty" "$multi" ''
}

# The -InputObject path of Resolve-Selection: the names a command was given, resolved against the
# OPTIONs its menu would show (the same list, in the same order, its own extra entries such as All
# or None included) without showing it, by the same matching as a menu answer: a number is the
# option at that position, a name matches case-insensitively, and both print the option's own
# spelling. An item that matches neither is printed as given, so the caller still reports it as it
# always has. One line per ITEM.
# Usage: foundation_resolve_items ITEM... -- OPTION...
foundation_resolve_items() {
	local items=()
	while [ $# -gt 0 ] && [ "$1" != -- ]; do
		items+=("$1")
		shift
	done
	[ $# -eq 0 ] || shift
	foundation__flat_options "$@"
	foundation__resolve_given ${items[@]+"${items[@]}"}
}

# Succeeds when an ITEM is a menu number (a whole number, or an index path such as 1.2 of the tree
# menu), so a command whose menu list is costly to build (one config read per project) builds it
# only when a number needs it. Usage: foundation_has_number ITEM...
foundation_has_number() {
	local item
	for item in "$@"; do [[ $item =~ ^[0-9]+(\.[0-9]+)*$ ]] && return 0; done
	return 1
}

# Hierarchical mode of Resolve-Selection (-GroupsConfig, ProcessGroupRecursive): NODEs are dotted
# paths in tree order, each parent before its children (AI, AI.Claude, GitHub, GitHub.Personal),
# optionally followed by a tab and the value to print for it (the path itself by default). The
# menu numbers them by position, 1, 1.1, 1.2, 2, 2.1, ..., indents each level by two spaces and
# shows the last segment; an answer item is an index path, a path, a node's name (its last
# segment) or its value, case-insensitive. Everything else is foundation_resolve_selection's.
# Usage: foundation_resolve_tree_selection TITLE PROMPT ALLOW-EMPTY MULTI NODE...
foundation_resolve_tree_selection() {
	local title=$1 prompt=$2 allow_empty=$3 multi=$4
	shift 4
	[ $# -gt 0 ] || return 1
	foundation__tree_options "$@"
	foundation__select "$title" "$prompt" "$allow_empty" "$multi" ''
}

# foundation_resolve_items for the tree menu: an ITEM is an index path (1.2), a path, a name or a
# value, as an answer to foundation_resolve_tree_selection is.
# Usage: foundation_resolve_tree_items ITEM... -- NODE...
foundation_resolve_tree_items() {
	local items=()
	while [ $# -gt 0 ] && [ "$1" != -- ]; do
		items+=("$1")
		shift
	done
	[ $# -eq 0 ] || shift
	foundation__tree_options "$@"
	foundation__resolve_given ${items[@]+"${items[@]}"}
}

# The flat menu's options: OPTION N is named by N and by itself.
# Usage: foundation__flat_options OPTION...
foundation__flat_options() {
	local option index=1
	FOUNDATION__SEL_VALUES=()
	FOUNDATION__SEL_KEYS=()
	FOUNDATION__SEL_LINES=()
	for option in "$@"; do
		FOUNDATION__SEL_VALUES+=("$option")
		FOUNDATION__SEL_KEYS+=("$index"$'\037'"$option")
		FOUNDATION__SEL_LINES+=("0"$'\t'"$index"$'\t'"$option")
		index=$((index + 1))
	done
}

# The tree menu's options: each NODE named by its index path, path, name and value.
# Usage: foundation__tree_options NODE...
foundation__tree_options() {
	local node path value name depth label i counters=()
	FOUNDATION__SEL_VALUES=()
	FOUNDATION__SEL_KEYS=()
	FOUNDATION__SEL_LINES=()
	for node in "$@"; do
		path=${node%%$'\t'*}
		value=$path
		case $node in *$'\t'*) value=${node#*$'\t'} ;; esac
		name=${path##*.}
		depth=$(printf '%s' "$path" | tr -cd '.' | wc -c | tr -d ' ')
		counters[depth]=$((${counters[depth]:-0} + 1))
		# A new node at this depth starts its children's numbering again.
		for ((i = depth + 1; i < ${#counters[@]}; i++)); do counters[i]=0; done
		label=${counters[0]:-0}
		for ((i = 1; i <= depth; i++)); do label="$label.${counters[i]:-0}"; done
		FOUNDATION__SEL_VALUES+=("$value")
		FOUNDATION__SEL_KEYS+=("$label"$'\037'"$path"$'\037'"$name"$'\037'"$value")
		FOUNDATION__SEL_LINES+=("$depth"$'\t'"$label"$'\t'"$name")
	done
}

# Each ITEM through foundation__select_resolve, or as given when it names no option.
# Usage: foundation__resolve_given ITEM...
foundation__resolve_given() {
	local item resolved
	for item in "$@"; do
		resolved=$(foundation__select_resolve "$item") || resolved=$item
		printf '%s\n' "$resolved"
	done
}

# A Yes/No question (Resolve-Selection -ConfirmationMessage): MESSAGE in red, Enter means No, so a
# confirmation never passes on muscle memory. Succeeds on Yes; fails on No and without a terminal
# (reported as such). Usage: foundation_confirm TITLE MESSAGE
foundation_confirm() {
	local answer
	FOUNDATION__SEL_VALUES=(Yes No)
	FOUNDATION__SEL_KEYS=("1"$'\037'"Yes"$'\037'"y" "2"$'\037'"No"$'\037'"n")
	FOUNDATION__SEL_LINES=("0"$'\t'"1"$'\t'"Yes" "0"$'\t'"2"$'\t'"No")
	answer=$(FOUNDATION_SELECTION_DEFAULT=No foundation__select "$1" "$2" 0 0 confirm) || return 1
	[ "$answer" = Yes ]
}

# Succeeds when a prompt can read the keyboard: FOUNDATION_TTY (the suites' answers file), else
# /dev/tty, exists and opens. A command that offers a menu only when it can be answered asks this
# instead of [ -t 0 ], so the suites can drive that menu.
foundation_has_terminal() {
	[ -r "${FOUNDATION_TTY:-/dev/tty}" ] && { : <"${FOUNDATION_TTY:-/dev/tty}"; } 2>/dev/null
}

# The prompt loop behind the three menus above, over FOUNDATION__SEL_VALUES (what an item resolves
# to), FOUNDATION__SEL_KEYS (the spellings that name it, separated by \037) and FOUNDATION__SEL_LINES
# (DEPTH<TAB>LABEL<TAB>TEXT per menu line). STYLE confirm draws the prompt in red.
# Usage: foundation__select TITLE PROMPT ALLOW-EMPTY MULTI STYLE
foundation__select() {
	local title=$1 prompt=$2 allow_empty=$3 multi=$4 style=$5
	if ! foundation_has_terminal; then
		log_error "No selection possible without a terminal - pass the name(s) as arguments"
		return 1
	fi
	local cyan='' green='' red='' reset=''
	if log_use_color 2; then
		cyan=$'\033[36m' green=$'\033[32m' red=$'\033[31m' reset=$'\033[0m'
	fi
	local line depth label text indent k
	printf '\n%s%s%s\n\n' "$cyan" "$title" "$reset" >&2
	for line in "${FOUNDATION__SEL_LINES[@]}"; do
		IFS=$'\t' read -r depth label text <<<"$line"
		indent=''
		for ((k = 0; k < depth; k++)); do indent="$indent  "; done
		printf ' %s%s[%s%s%s%s]%s %s\n' "$indent" "$cyan" "$reset" "$green" "$label" "$cyan" "$reset" "$text" >&2
	done

	# Resolve-Selection's defaults: a prompt when the caller gives none, and the suffix that
	# tells a multi-select menu apart.
	if [ -z "$prompt" ]; then
		if [ "$multi" = "1" ]; then prompt="Enter selection(s) by number or name"; else prompt="Enter selection by number or name"; fi
	fi
	local suffix=': '
	[ "$multi" = "1" ] && suffix=' (space/comma-separated): '
	local default='' prompt_color=''
	[ "$style" = confirm ] && prompt_color=$red
	if [ -n "${FOUNDATION_SELECTION_DEFAULT:-}" ]; then
		default=$(foundation__select_resolve "$FOUNDATION_SELECTION_DEFAULT") || default=''
		[ -n "$default" ] && prompt="$prompt (default: $default)"
	fi

	local reply items item chosen invalid resolved n existing duplicate
	while :; do
		printf '\n%s%s%s%s' "$prompt_color" "$prompt" "$suffix" "$reset" >&2
		IFS= read -r reply <"${FOUNDATION_TTY:-/dev/tty}" || return 1
		reply=$(foundation_trim "$reply")
		if [ -z "$reply" ]; then
			if [ -n "$default" ]; then
				printf '%s\n' "$default"
				return 0
			fi
			[ "$allow_empty" = "1" ] && return 0
			printf '\n%s=> Empty input is not allowed. Make a selection!%s\n' "$red" "$reset" >&2
			continue
		fi
		items=()
		IFS=$', \t' read -r -a items <<<"$reply"
		chosen=()
		invalid=()
		for item in "${items[@]}"; do
			[ -n "$item" ] || continue
			if ! resolved=$(foundation__select_resolve "$item"); then
				invalid+=("$item")
				continue
			fi
			# Each option once, in the order given.
			duplicate=0
			for existing in ${chosen[@]+"${chosen[@]}"}; do [ "$existing" = "$resolved" ] && duplicate=1; done
			[ "$duplicate" -eq 1 ] || chosen+=("$resolved")
		done
		if [ ${#invalid[@]} -gt 0 ]; then
			for n in "${invalid[@]}"; do printf '\n%s=> Invalid selection => [%s]%s' "$red" "$n" "$reset" >&2; done
			printf '\n\n%s  Please try again!%s\n' "$cyan" "$reset" >&2
			continue
		fi
		if [ "$multi" != "1" ] && [ ${#chosen[@]} -gt 1 ]; then
			printf '\n%s=> Only one selection is allowed!%s\n' "$red" "$reset" >&2
			continue
		fi
		printf '%s\n' "${chosen[@]}"
		return 0
	done
}

# The value of the option ITEM names: one of its keys, compared case-insensitively.
# Usage: foundation__select_resolve ITEM
foundation__select_resolve() {
	local i key keys
	for ((i = 0; i < ${#FOUNDATION__SEL_KEYS[@]}; i++)); do
		IFS=$'\037' read -r -a keys <<<"${FOUNDATION__SEL_KEYS[i]}"
		for key in "${keys[@]}"; do
			if foundation_ieq "$key" "$1"; then
				printf '%s' "${FOUNDATION__SEL_VALUES[i]}"
				return 0
			fi
		done
	done
	return 1
}

# ---------------------------------------------------------------------------------------------
# Run directory: per-invocation scratch shared between an Open-Workspace and the commands it
# runs (pre-existing window snapshot, deferred terminal commands).
# ---------------------------------------------------------------------------------------------

foundation_run_dir() {
	if [ -z "${FOUNDATION_RUN_DIR:-}" ] || [ ! -d "$FOUNDATION_RUN_DIR" ]; then
		FOUNDATION_RUN_DIR=$(mktemp -d "${TMPDIR:-/tmp}/foundation.XXXXXX") || return 1
		export FOUNDATION_RUN_DIR
	fi
	printf '%s' "$FOUNDATION_RUN_DIR"
}
