#!/usr/bin/env bats
# Test-MachineOnline against a ping stand-in (no packet ever leaves): a configured machine is
# pinged at its address, anything else as given; the exit status says online (0) or not (1),
# a machine without an address is unknown, and --wait-for-online polls until --timeout-seconds.

load ../../helpers

setup() {
	setup_foundation
	copy_fixture_config
	cat >"$FOUNDATION_CONFIG_DIR/wake-on-lan.conf" <<'EOF'
[Server]
mac 00:11:22:33:44:55
broadcast 192.168.1.255
address 192.168.1.10

[Desktop]
mac AA-BB-CC-DD-EE-FF
broadcast 192.168.1.255
EOF
	# Online are the addresses listed in this file; ping's last argument is the address.
	online=$BATS_TEST_TMPDIR/online
	: >"$online"
	stub_tool ping "for a in \"\$@\"; do last=\$a; done; grep -qxF \"\$last\" '$online'"
	[ "$(command -v ping)" = "$BATS_TEST_TMPDIR/tools/ping" ]
	log=$BATS_TEST_TMPDIR/tool.log
	: >"$log"
	cmd=$UNIX_DIR/modules/System/bin/Test-MachineOnline
}

pinged() {
	grep -qE "^ping .* $1\$" "$log"
}

pings() {
	grep -c '^ping ' "$log" || true
}

@test "a configured machine is pinged at its address and answers" {
	echo 192.168.1.10 >"$online"
	run "${BASH:-bash}" "$cmd" server
	[ "$status" -eq 0 ]
	pinged '192\.168\.1\.10'
	[ "$(pings)" -eq 1 ]
}

@test "a machine that does not answer exits 1" {
	run "${BASH:-bash}" "$cmd" Server
	[ "$status" -eq 1 ]
	pinged '192\.168\.1\.10'
}

@test "anything that is no configured machine is pinged as given" {
	echo 10.0.0.7 >"$online"
	run "${BASH:-bash}" "$cmd" 10.0.0.7
	[ "$status" -eq 0 ]
	pinged '10\.0\.0\.7'
	run "${BASH:-bash}" "$cmd" --address other-host
	[ "$status" -eq 1 ]
	pinged 'other-host'
}

@test "without wake-on-lan.conf the name is pinged as an address" {
	export FOUNDATION_CONFIG_DIR=$FIXTURE_CONFIG
	run "${BASH:-bash}" "$cmd" Server
	[ "$status" -eq 1 ]
	pinged 'Server'
}

@test "a configured machine without an address is unknown: exit 1, no ping" {
	run "${BASH:-bash}" "$cmd" Desktop
	[ "$status" -eq 1 ]
	[ "$(pings)" -eq 0 ]
}

@test "--wait-for-online succeeds once it answers, and gives up after --timeout-seconds" {
	echo 192.168.1.10 >"$online"
	run "${BASH:-bash}" "$cmd" Server --wait-for-online
	[ "$status" -eq 0 ]
	[ "$(pings)" -eq 1 ]
	: >"$online"
	: >"$log"
	run "${BASH:-bash}" "$cmd" Server --wait-for-online --timeout-seconds 0
	[ "$status" -eq 1 ]
	[ "$(pings)" -eq 0 ]
}

@test "--quiet prints nothing and keeps the exit status" {
	run "${BASH:-bash}" "$cmd" Server --quiet
	[ "$status" -eq 1 ]
	[ -z "$output" ]
	run "${BASH:-bash}" "$cmd" Desktop --quiet
	[ "$status" -eq 1 ]
	[ -z "$output" ]
}

@test "--machine names the target and --display-name is the name the messages use, as on Windows" {
	echo 192.168.1.10 >"$online"
	run "${BASH:-bash}" "$cmd" --display-name Label --machine Server
	[ "$status" -eq 0 ]
	pinged '192\.168\.1\.10'
	! grep -q 'Label' "$log" || false
	[[ $output == *"Label is online"* ]]
	[[ $output != *"Server (192.168.1.10)"* ]]
}

@test "without a target it fails and pings nothing" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[ "$(pings)" -eq 0 ]
}

@test "--ping-timeout-milliseconds is the ping's timeout, rounded up to whole seconds" {
	echo 192.168.1.10 >"$online"
	run "${BASH:-bash}" "$cmd" Server -PingTimeoutMilliseconds 1500
	[ "$status" -eq 0 ]
	grep -qE '^ping -c 1 (-t|-W) 2 192\.168\.1\.10$' "$log"
	: >"$log"
	run "${BASH:-bash}" "$cmd" Server
	grep -qE '^ping -c 1 (-t|-W) 1 192\.168\.1\.10$' "$log"
}

@test "--interval-seconds and the ping timeout take whole numbers; a bad one pings nothing" {
	run "${BASH:-bash}" "$cmd" Server --interval-seconds 0
	[ "$status" -eq 1 ]
	run "${BASH:-bash}" "$cmd" Server --ping-timeout-milliseconds soon
	[ "$status" -eq 1 ]
	[ "$(pings)" -eq 0 ]
}

@test "an unknown flag is an error, never the target" {
	echo 3 >"$online"
	run "${BASH:-bash}" "$cmd" Server -Bogus 3
	[ "$status" -eq 1 ]
	[[ $output == *"Unknown argument => --bogus"* ]]
	[ "$(pings)" -eq 0 ]
}
