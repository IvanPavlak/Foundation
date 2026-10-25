# shellcheck shell=bash
# Reachability helpers shared by Send-WakeOnLan and Test-MachineOnline. Needs lib/config.sh.

# Does ADDRESS answer one ping within SECONDS (default 1)? The flags differ: BSD ping (macOS)
# takes -t as the overall timeout, iputils ping (Linux) takes -W in seconds.
# Usage: net_ping ADDRESS [SECONDS]
net_ping() {
	local seconds=${2:-1}
	if [ "$(uname)" = Darwin ]; then
		ping -c 1 -t "$seconds" "$1" >/dev/null 2>&1
	else
		ping -c 1 -W "$seconds" "$1" >/dev/null 2>&1
	fi
}

# Whole seconds for a ping timeout of MILLISECONDS, rounded up (ping takes seconds only), so
# -PingTimeoutMilliseconds 1500 waits 2 s and 1000 waits 1 s. Usage: net_seconds MILLISECONDS
net_seconds() {
	printf '%s' $((($1 + 999) / 1000))
}

# Polls ADDRESS until it answers or TIMEOUT seconds pass, INTERVAL seconds (default 1) between
# pings, each ping waiting PING SECONDS (default 1).
# Usage: net_wait_online ADDRESS TIMEOUT [INTERVAL [PING]]
net_wait_online() {
	local address=$1 timeout=$2 interval=${3:-1} ping=${4:-1} start
	start=$SECONDS
	while [ $((SECONDS - start)) -lt "$timeout" ]; do
		net_ping "$address" "$ping" && return 0
		sleep "$interval"
	done
	return 1
}

# `address` of machine NAME in wake-on-lan.conf (the WakeOnLanConfig Address field).
net_machine_address() {
	local file name
	file=$(conf_path wake-on-lan.conf) || return 1
	name=$(conf_section_name "$file" "$1") || return 1
	conf_section "$file" "$name" | awk '$1 == "address" { print $2; found = 1 } END { exit found ? 0 : 1 }'
}
