# shellcheck shell=bash
# Step toggles shared by every command that runs a configurable list of steps (Bootstrap,
# Kill-All, Set-SystemTheme): the Resolve-Steps analog of the Windows Helper module.
#
# A command fills three variables, then asks step_on per step:
#
#   STEP_CONFIG     path of its config file (kill-all.conf, bootstrap.conf, ...) or empty; its
#                   `step NAME on|off` lines are read through conf_lines, so NAME.local.conf is
#                   layered over the base file and a later line wins
#   STEP_SKIPS      array of step names forced off for this run (--skip)
#   STEP_INCLUDES   array of step names forced on for this run (--include)
#
# Precedence, lowest to highest, as on Windows: the DEFAULT the command passes, the config
# lines, --include, --skip. A name in both lists is skipped with one warning. Names compare
# case-insensitively, like PowerShell hashtable keys. Needs lib/config.sh.
#
# Written to run under bash 3.2 too, like the rest of lib/, so the suites run on a stock macOS.

STEP_CONFIG=${STEP_CONFIG:-}
STEP__WARNED=' '

# Usage: step_on NAME [DEFAULT]   (DEFAULT on|off, off when omitted). Succeeds when NAME runs.
step_on() {
	local name=$1 state=${2:-off} line kind step value item skipped=0 included=0
	if [ -n "$STEP_CONFIG" ] && [ -r "$STEP_CONFIG" ]; then
		while IFS= read -r line; do
			read -r kind step value _ <<<"$line"
			[ "$kind" = step ] && foundation_ieq "$step" "$name" && state=$(foundation_lower "$value")
		done < <(conf_lines "$STEP_CONFIG")
	fi
	for item in ${STEP_INCLUDES[@]+"${STEP_INCLUDES[@]}"}; do foundation_ieq "$item" "$name" && included=1; done
	for item in ${STEP_SKIPS[@]+"${STEP_SKIPS[@]}"}; do foundation_ieq "$item" "$name" && skipped=1; done
	if [ "$skipped" -eq 1 ]; then
		if [ "$included" -eq 1 ]; then
			case $STEP__WARNED in
				*" $(foundation_lower "$name") "*) ;;
				*)
					log_warning "Step [$name] is in both --skip and --include - skipping it!"
					STEP__WARNED="$STEP__WARNED$(foundation_lower "$name") "
					;;
			esac
		fi
		return 1
	fi
	[ "$included" -eq 1 ] && return 0
	[ "$state" = on ]
}

# Appends the comma- or space-separated names in VALUE to the array named LIST (STEP_SKIPS or
# STEP_INCLUDES), so `--skip Docker,Browsers` works as `-Skip Docker, Browsers` does in
# PowerShell. Usage: steps_add LIST VALUE
steps_add() {
	local list=$1 value=$2 item names
	IFS=', ' read -r -a names <<<"$value"
	for item in ${names[@]+"${names[@]}"}; do
		[ -n "$item" ] || continue
		eval "$list+=(\"\$item\")"
	done
}

# Stops the command when STEP_SKIPS or STEP_INCLUDES names a step that is not one of KNOWN
# (case-insensitive), the ValidateSet of Windows: `--skip Dokcer` must not silently run the step
# it meant to skip. Usage: steps_validate KNOWN...
steps_validate() {
	local item known found
	for item in ${STEP_SKIPS[@]+"${STEP_SKIPS[@]}"} ${STEP_INCLUDES[@]+"${STEP_INCLUDES[@]}"}; do
		found=0
		for known in "$@"; do
			if foundation_ieq "$item" "$known"; then
				found=1
				break
			fi
		done
		[ "$found" -eq 1 ] || foundation_die "Unknown step [$item] (expected $*) - nothing was done"
	done
}

# ---------------------------------------------------------------------------------------------
# One administrator prompt per run
# ---------------------------------------------------------------------------------------------

STEP__SUDO_PID=''

# Asks for the administrator password once (sudo -v) and keeps the credential fresh in the
# background until steps_sudo_stop or the calling shell exits, so every root step of a run
# shares that one prompt. Fails, and starts nothing, when sudo is refused.
steps_sudo_keepalive() {
	[ -z "$STEP__SUDO_PID" ] || return 0
	sudo -v || return 1
	local parent=$$
	# Every descriptor beyond stderr is closed: a refresher holding one the caller's caller waits
	# on (bats waits for its fd 3) would keep that caller waiting up to 50 seconds after the run.
	(
		while kill -0 "$parent" 2>/dev/null; do
			sudo -n -v 2>/dev/null
			sleep 50
		done
	) </dev/null >/dev/null 2>&1 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&- &
	STEP__SUDO_PID=$!
}

# Stops the keep-alive of steps_sudo_keepalive (safe to call when none runs).
steps_sudo_stop() {
	[ -n "$STEP__SUDO_PID" ] || return 0
	# The sleeping child goes first, or it outlives the loop by up to 50 seconds. Each call reports
	# the refresher's end as a failure (kill: already gone; wait: 143, killed by SIGTERM), which
	# must not abort a caller running under `set -e` (bats does).
	pkill -P "$STEP__SUDO_PID" 2>/dev/null || true
	kill "$STEP__SUDO_PID" 2>/dev/null || true
	wait "$STEP__SUDO_PID" 2>/dev/null || true
	STEP__SUDO_PID=''
	return 0
}
