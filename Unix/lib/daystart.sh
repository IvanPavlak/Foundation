# shellcheck shell=bash
# Day boundary of the once-per-day frequency of startup tasks (Test-StartupTaskDue on Windows).
# POSIX sh, so the shared shell rc could source it in zsh and bash alike; lib/startup.sh uses it
# for the stamps and for the day boundary it records for the shell's prompt check.

# Prints the epoch second the current day began, for a day that starts at HOUR:00 local time:
# today at HOUR, or yesterday at HOUR while it is still earlier than that - so work past midnight
# stays on the day before. Add 86400 for the next boundary. A day is taken as 24 hours, so on the
# two daylight-saving nights a year the boundary is an hour off for one day.
# Usage: foundation_day_start HOUR
foundation_day_start() {
	# Leading zeros stripped: bash reads 08 and 09 as broken octal numbers.
	_foundation_hour=${1#0}
	# One date call for every field; zsh and bash both split the unquoted substitution.
	# shellcheck disable=SC2046
	set -- $(date '+%s %H %M %S')
	_foundation_start=$(($1 - ${2#0} * 3600 - ${3#0} * 60 - ${4#0} + ${_foundation_hour:-0} * 3600))
	[ "$1" -ge "$_foundation_start" ] || _foundation_start=$((_foundation_start - 86400))
	printf '%s\n' "$_foundation_start"
	unset _foundation_hour _foundation_start
}
