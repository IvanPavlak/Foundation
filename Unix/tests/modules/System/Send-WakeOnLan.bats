#!/usr/bin/env bats
# Send-WakeOnLan against python3 and ping stand-ins (no packet ever leaves): the packet goes to the
# configured MAC, broadcast and port, an online machine gets none, a machine with an address is
# waited for (--no-wait pings nothing), the menu's Enter wakes the default machine, and unknown or
# incomplete machines fail the run without stopping the others; None or All given as a name
# cancels or wakes every machine.

load ../../helpers

setup() {
	setup_foundation
	copy_fixture_config
	cat >"$FOUNDATION_CONFIG_DIR/wake-on-lan.conf" <<'EOF'
default Server

[Server]
mac 00:11:22:33:44:55
broadcast 192.168.1.255
port 7
address 192.168.1.10

[Desktop]
mac AA-BB-CC-DD-EE-FF
broadcast 192.168.1.255

[Broken]
broadcast 192.168.1.255
EOF
	online=$BATS_TEST_TMPDIR/online
	# The packet sender reads its script from stdin; with wakes-up a sent packet brings the
	# machine online, so the wait after it succeeds on its first ping.
	stub_tool python3 "cat >/dev/null; [ -f '$BATS_TEST_TMPDIR/python-fails' ] && exit 1; [ -f '$BATS_TEST_TMPDIR/wakes-up' ] && touch '$online'; exit 0"
	stub_tool ping "[ -f '$online' ]"
	[ "$(command -v python3)" = "$BATS_TEST_TMPDIR/tools/python3" ]
	[ "$(command -v ping)" = "$BATS_TEST_TMPDIR/tools/ping" ]
	log=$BATS_TEST_TMPDIR/tool.log
	: >"$log"
	cmd=$UNIX_DIR/modules/System/bin/Send-WakeOnLan
}

answers() {
	printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/answers"
	export FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers
}

sent() { # MAC BROADCAST PORT
	grep -qx "python3 - $1 $2 $3" "$log"
}

count() {
	grep -c "^$1 " "$log" || true
}

@test "an offline machine gets the packet at its MAC, broadcast and port; --no-wait pings nothing" {
	run "${BASH:-bash}" "$cmd" server --no-wait
	[ "$status" -eq 0 ]
	sent 00:11:22:33:44:55 192.168.1.255 7
	[ "$(count ping)" -eq 0 ]
}

@test "--no-wait skips the already-online check too: an online machine still gets the packet" {
	touch "$online"
	run "${BASH:-bash}" "$cmd" Server --no-wait
	[ "$status" -eq 0 ]
	sent 00:11:22:33:44:55 192.168.1.255 7
	[ "$(count ping)" -eq 0 ]
}

@test "a machine that already answers gets no packet" {
	touch "$online"
	run "${BASH:-bash}" "$cmd" Server
	[ "$status" -eq 0 ]
	[ "$(count python3)" -eq 0 ]
}

@test "after the packet the machine is waited for until it answers" {
	touch "$BATS_TEST_TMPDIR/wakes-up"
	run "${BASH:-bash}" "$cmd" Server
	[ "$status" -eq 0 ]
	sent 00:11:22:33:44:55 192.168.1.255 7
	[ "$(count ping)" -eq 2 ]
	grep -qE '^ping .*192\.168\.1\.10$' "$log"
}

@test "a machine that does not answer within --timeout-seconds fails the run" {
	run "${BASH:-bash}" "$cmd" Server --timeout-seconds 0
	[ "$status" -eq 1 ]
	sent 00:11:22:33:44:55 192.168.1.255 7
}

@test "a machine without an address is fire-and-forget on port 9, with a warning that it cannot be confirmed" {
	run "${BASH:-bash}" "$cmd" Desktop
	[ "$status" -eq 0 ]
	sent AA-BB-CC-DD-EE-FF 192.168.1.255 9
	[ "$(count ping)" -eq 0 ]
	[[ $output == *"[Desktop] has no address"* ]]
	run "${BASH:-bash}" "$cmd" Desktop --no-wait
	[ "$status" -eq 0 ]
	[[ $output != *"has no address"* ]]
}

@test "an unknown or incomplete machine fails the run, the others are still woken" {
	run "${BASH:-bash}" "$cmd" Nope Broken Desktop
	[ "$status" -eq 1 ]
	[ "$(count python3)" -eq 1 ]
	sent AA-BB-CC-DD-EE-FF 192.168.1.255 9
}

@test "--all wakes every machine" {
	run "${BASH:-bash}" "$cmd" --all --no-wait
	[ "$status" -eq 1 ]
	sent 00:11:22:33:44:55 192.168.1.255 7
	sent AA-BB-CC-DD-EE-FF 192.168.1.255 9
	[ "$(count python3)" -eq 2 ]
}

@test "a packet that cannot be sent fails the run" {
	touch "$BATS_TEST_TMPDIR/python-fails"
	run "${BASH:-bash}" "$cmd" Desktop
	[ "$status" -eq 1 ]
}

@test "without a name the menu chooses; Enter wakes the default machine, as on Windows" {
	answers 2
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	sent AA-BB-CC-DD-EE-FF 192.168.1.255 9
	: >"$log"
	answers ''
	run "${BASH:-bash}" "$cmd" --no-wait
	[ "$status" -eq 0 ]
	[[ $output == *"default => Server"* ]]
	sent 00:11:22:33:44:55 192.168.1.255 7
	[ "$(count python3)" -eq 1 ]
}

@test "the menu's None cancels and All wakes every machine" {
	answers none
	run "${BASH:-bash}" "$cmd" --no-wait
	[ "$status" -eq 0 ]
	[ "$(count python3)" -eq 0 ]
	answers 'Desktop, None'
	run "${BASH:-bash}" "$cmd" --no-wait
	[ "$status" -eq 0 ]
	[ "$(count python3)" -eq 0 ]
	answers all
	run "${BASH:-bash}" "$cmd" --no-wait
	# Broken has no mac: the others are still woken and the run fails.
	[ "$status" -eq 1 ]
	sent 00:11:22:33:44:55 192.168.1.255 7
	sent AA-BB-CC-DD-EE-FF 192.168.1.255 9
	[ "$(count python3)" -eq 2 ]
}

@test "None as a name cancels in any case, as -Machine None does on Windows; a workspace passes it on" {
	for name in None none NONE; do
		run "${BASH:-bash}" "$cmd" "$name" </dev/null
		[ "$status" -eq 0 ]
		[[ $output == *"Wake-on-LAN cancelled!"* ]]
	done
	run "${BASH:-bash}" "$cmd" --machine Desktop,None --no-wait </dev/null
	[ "$status" -eq 0 ]
	FOUNDATION_WORKSPACE_OPEN=1 run "${BASH:-bash}" "$cmd" --machine None </dev/null
	[ "$status" -eq 0 ]
	[ "$(count python3)" -eq 0 ]
	[ "$(count ping)" -eq 0 ]
}

@test "a number names that entry of the menu, None and All included, as -Machine 2 does on Windows" {
	run "${BASH:-bash}" "$cmd" 2 --no-wait </dev/null
	[ "$status" -eq 0 ]
	sent AA-BB-CC-DD-EE-FF 192.168.1.255 9
	[ "$(count python3)" -eq 1 ]
	# Server, Desktop, Broken, All, None: 5 is None.
	run "${BASH:-bash}" "$cmd" 5 </dev/null
	[ "$status" -eq 0 ]
	[[ $output == *"Wake-on-LAN cancelled!"* ]]
	[ "$(count python3)" -eq 1 ]
}

@test "All as a name wakes every machine in any case, as --all does" {
	run "${BASH:-bash}" "$cmd" all --no-wait </dev/null
	# Broken has no mac: the others are still woken and the run fails.
	[ "$status" -eq 1 ]
	sent 00:11:22:33:44:55 192.168.1.255 7
	sent AA-BB-CC-DD-EE-FF 192.168.1.255 9
	[ "$(count python3)" -eq 2 ]
}

@test "Enter at the menu without a default machine sends nothing" {
	grep -v '^default' "$FOUNDATION_CONFIG_DIR/wake-on-lan.conf" >"$BATS_TEST_TMPDIR/wol" && mv "$BATS_TEST_TMPDIR/wol" "$FOUNDATION_CONFIG_DIR/wake-on-lan.conf"
	answers ''
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(count python3)" -eq 0 ]
}

@test "without a name and without a terminal nothing is sent" {
	run "${BASH:-bash}" "$cmd" </dev/null
	[ "$status" -ne 0 ]
	[ "$(count python3)" -eq 0 ]
}

@test "a workspace action without a name wakes the default machine" {
	FOUNDATION_WORKSPACE_OPEN=1 run "${BASH:-bash}" "$cmd" --no-wait </dev/null
	[ "$status" -eq 0 ]
	sent 00:11:22:33:44:55 192.168.1.255 7
}

@test "a workspace action without a default machine sends nothing" {
	grep -v '^default' "$FOUNDATION_CONFIG_DIR/wake-on-lan.conf" >"$BATS_TEST_TMPDIR/wol" && mv "$BATS_TEST_TMPDIR/wol" "$FOUNDATION_CONFIG_DIR/wake-on-lan.conf"
	FOUNDATION_WORKSPACE_OPEN=1 run "${BASH:-bash}" "$cmd" </dev/null
	[ "$status" -eq 0 ]
	[ "$(count python3)" -eq 0 ]
}

@test "without wake-on-lan.conf it fails and sends nothing" {
	export FOUNDATION_CONFIG_DIR=$FIXTURE_CONFIG
	run "${BASH:-bash}" "$cmd" Server
	[ "$status" -ne 0 ]
	[ "$(count python3)" -eq 0 ]
}

@test "a comma list names several machines, as -Machine Server,Desktop does" {
	run "${BASH:-bash}" "$cmd" -Machine Server,Desktop --no-wait
	[ "$status" -eq 0 ]
	sent 00:11:22:33:44:55 192.168.1.255 7
	sent AA-BB-CC-DD-EE-FF 192.168.1.255 9
}

@test "an unknown flag is an error, never a machine: no packet is sent" {
	run "${BASH:-bash}" "$cmd" Server --no-wiat
	[ "$status" -eq 1 ]
	[[ $output == *"Unknown argument => --no-wiat"* ]]
	[ "$(count python3)" -eq 0 ]
	[ "$(count ping)" -eq 0 ]
}
