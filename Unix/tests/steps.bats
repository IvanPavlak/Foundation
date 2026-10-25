#!/usr/bin/env bats
# lib/steps.sh: step_on precedence (default < config < local overlay < --include < --skip), the
# both-lists warning, comma lists, and the one-prompt sudo keep-alive against a sudo stand-in.

load helpers

setup() {
	setup_foundation
	foundation_load steps
	use_empty_config
	STEP_CONFIG=$FOUNDATION_CONFIG_DIR/demo.conf
	cat >"$STEP_CONFIG" <<'EOF'
# comment
step Alpha on
step Beta  off
step gamma ON
keep Something else
EOF
	STEP_SKIPS=()
	STEP_INCLUDES=()
}

@test "the default applies when the config has no line for the step" {
	run step_on Delta
	[ "$status" -ne 0 ]
	run step_on Delta on
	[ "$status" -eq 0 ]
}

@test "config lines beat the default, case-insensitively" {
	step_on Alpha off
	! step_on Beta on || false
	step_on GAMMA off
}

@test "a missing or empty config falls back to the default" {
	STEP_CONFIG=''
	step_on Alpha on
	! step_on Alpha || false
	STEP_CONFIG=$FOUNDATION_CONFIG_DIR/missing.conf
	step_on Alpha on
}

@test "the local overlay is read after the base file, so its line wins" {
	echo 'step Alpha off' >"$FOUNDATION_CONFIG_DIR/demo.local.conf"
	! step_on Alpha on || false
	echo 'step Beta on' >>"$FOUNDATION_CONFIG_DIR/demo.local.conf"
	step_on Beta off
}

@test "--include turns a step on over the config, --skip turns it off" {
	STEP_INCLUDES=(beta)
	step_on Beta
	STEP_SKIPS=(ALPHA)
	! step_on Alpha on || false
}

@test "a step in both lists is skipped, with one warning however often it is asked" {
	run bash -c '. "$1/lib/foundation.sh"; foundation_load config steps; STEP_CONFIG=$2; STEP_SKIPS=(Alpha); STEP_INCLUDES=(alpha)
		step_on Alpha on && echo RAN; step_on Alpha on && echo RAN; true' _ "$UNIX_DIR" "$STEP_CONFIG"
	[ "$status" -eq 0 ]
	[[ $output != *RAN* ]]
	[ "$(printf '%s\n' "$output" | grep -c 'both --skip and --include')" -eq 1 ]
}

@test "steps_add splits comma and space lists" {
	steps_add STEP_SKIPS "Docker,Browsers"
	steps_add STEP_SKIPS "VisibleWindows, NamedProcesses"
	[ "${#STEP_SKIPS[@]}" -eq 4 ]
	[ "${STEP_SKIPS[3]}" = NamedProcesses ]
	! step_on Browsers on || false
}

@test "steps_sudo_keepalive asks once, a second call does nothing, stop ends the refresher" {
	stub_tool sudo 'exit 0'
	steps_sudo_keepalive
	steps_sudo_keepalive
	[ "$(grep -c '^sudo -v$' "$BATS_TEST_TMPDIR/tool.log")" -eq 1 ]
	[ -n "$STEP__SUDO_PID" ]
	pid=$STEP__SUDO_PID
	steps_sudo_stop
	[ -z "$STEP__SUDO_PID" ]
	! kill -0 "$pid" 2>/dev/null || false
}

@test "steps_sudo_keepalive fails and starts nothing when sudo is refused" {
	stub_tool sudo 'exit 1'
	run steps_sudo_keepalive
	[ "$status" -ne 0 ]
	[ -z "$STEP__SUDO_PID" ]
	steps_sudo_stop
}

@test "step lines take @TYPE, and the overlay's later line still wins" {
	printf '%s\n' 'step Power off' '@Laptop step Power on' >"$STEP_CONFIG"
	CONF_MACHINE_TYPE=Laptop run step_on Power
	[ "$status" -eq 0 ]
	CONF_MACHINE_TYPE=Work run step_on Power
	[ "$status" -ne 0 ]
	printf '%s\n' '@Laptop step Power off' >"$FOUNDATION_CONFIG_DIR/demo.local.conf"
	CONF_MACHINE_TYPE=Laptop run step_on Power
	[ "$status" -ne 0 ]
}

@test "steps_validate passes known names in any case and stops on an unknown one" {
	STEP_SKIPS=(alpha)
	STEP_INCLUDES=(BETA)
	run steps_validate Alpha Beta Gamma
	[ "$status" -eq 0 ]
	STEP_INCLUDES=(Beta Dokcer)
	run steps_validate Alpha Beta Gamma
	[ "$status" -eq 1 ]
	[[ $output == *"Unknown step [Dokcer] (expected Alpha Beta Gamma)"* ]]
}
