#!/usr/bin/env bats
# Set-StartupTasks against a stand-in launchctl (an agent counts as loaded while $LOADED is set)
# and an agents folder under the test folder (FOUNDATION_LAUNCH_AGENTS_DIR), so no test registers
# a real agent: nothing without a valid, enabled sign-in task in this Mac's scope, the agent file
# written (never loaded) and left alone when up to date, --dry-run and --list, a stale agent
# unloaded and removed, --remove, and a property list plutil accepts.

load ../../helpers

setup() {
	setup_foundation
	use_empty_config
	export FOUNDATION_LOG_DIR=$BATS_TEST_TMPDIR/logs CONF_MACHINE_TYPE=Work
	export FOUNDATION_LAUNCH_AGENTS_DIR=$BATS_TEST_TMPDIR/agents
	agents=$FOUNDATION_LAUNCH_AGENTS_DIR
	agent=$agents/foundation.StartupTasks-SignIn.plist
	stub_tool launchctl 'case "$1" in print) [ -n "$LOADED" ] || exit 1 ;; esac; exit 0'
	[ "$(command -v launchctl)" = "$BATS_TEST_TMPDIR/tools/launchctl" ] || {
		echo "stub guard: launchctl resolves to $(command -v launchctl)" >&2
		return 1
	}
	cmd=$UNIX_DIR/modules/Bootstrap/bin/Set-StartupTasks
}

conf() { printf '%s\n' "$@" >"$FOUNDATION_CONFIG_DIR/startup.conf"; }
launchctl_calls() { grep '^launchctl' "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null | grep -v '^launchctl print' || true; }

@test "no sign-in task: nothing is written, not even the agents folder" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -e "$agents" ]
	conf "[Terminal]" "command true" "trigger TerminalOpen" \
		"[Parked]" "command true" "trigger SignIn" "enabled off" \
		"[Elsewhere]" "command true" "trigger SignIn" "machine Laptop" \
		"[Broken]" "command true" "trigger SignIn" "colour blue" \
		"[OtherType]" "@Laptop command true" "@Laptop trigger SignIn"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -e "$agents" ]
	[ -z "$(launchctl_calls)" ]
}

@test "a sign-in task writes the one agent, without loading it; a second run changes nothing" {
	conf "[One]" "command true" "trigger SignIn" "[Two]" "command true" "trigger SignIn TerminalOpen"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -f "$agent" ]
	[ "$(find "$agents" -type f | wc -l | tr -d ' ')" -eq 1 ]
	grep -q '<string>foundation.StartupTasks-SignIn</string>' "$agent"
	grep -q '<string>SignIn</string>' "$agent"
	grep -qF "<string>$UNIX_DIR/modules/Workflow/bin/Invoke-StartupTasks</string>" "$agent"
	# Written, not loaded: loading it now would run the sign-in tasks at once.
	[ -z "$(launchctl_calls)" ]
	touch -t 200001010000 "$agent"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"up to date"* ]]
	# Not rewritten: the file keeps its time from 2000.
	[ "$(stat -c %Y "$agent" 2>/dev/null || stat -f %m "$agent")" -lt 1000000000 ]
}

@test "an agent that differs from what would be written is written again" {
	conf "[One]" "command true" "trigger SignIn"
	mkdir -p "$agents" && echo old >"$agent"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	grep -q 'Invoke-StartupTasks' "$agent"
}

@test "the agent file is a property list plutil accepts" {
	command -v plutil >/dev/null 2>&1 || skip "plutil is not installed"
	conf "[One]" "command true" "trigger SignIn"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	plutil -lint "$agent"
}

@test "--dry-run says what it would write and remove and changes nothing" {
	conf "[One]" "command true" "trigger SignIn"
	run "${BASH:-bash}" "$cmd" --dry-run
	[ "$status" -eq 0 ]
	[[ $output == *"write $agent"* ]]
	[ ! -e "$agents" ]
	mkdir -p "$agents" && echo old >"$agents/foundation.StartupTasks-Unlock.plist"
	conf "[One]" "command true" "trigger TerminalOpen"
	run "${BASH:-bash}" "$cmd" --dry-run
	[[ $output == *"remove $agents/foundation.StartupTasks-Unlock.plist"* ]]
	[ -e "$agents/foundation.StartupTasks-Unlock.plist" ]
	[ -z "$(launchctl_calls)" ]
}

@test "--list: Missing, Registered, Outdated and Stale, and whether launchd has it loaded; changes nothing" {
	run "${BASH:-bash}" "$cmd" --list
	[ "$status" -eq 0 ]
	[[ $output == *"No startup task needs an agent"* ]]
	conf "[One]" "command true" "trigger SignIn"
	run "${BASH:-bash}" "$cmd" --list
	[[ $output =~ foundation.StartupTasks-SignIn\ +SignIn\ +Missing\ +loaded:\ no ]]
	[ ! -e "$agents" ]
	run "${BASH:-bash}" "$cmd"
	LOADED=1 run "${BASH:-bash}" "$cmd" --list
	[[ $output =~ SignIn\ +Registered\ +loaded:\ yes ]]
	echo changed >>"$agent"
	run "${BASH:-bash}" "$cmd" --list
	[[ $output =~ SignIn\ +Outdated ]]
	conf "[One]" "command true" "trigger TerminalOpen"
	run "${BASH:-bash}" "$cmd" --list
	[[ $output =~ SignIn\ +Stale ]]
	[ -e "$agent" ]
	[ -z "$(launchctl_calls)" ]
}

@test "an agent nothing needs any more is unloaded when loaded and removed; other agents are left alone" {
	mkdir -p "$agents"
	echo old >"$agent"
	echo old >"$agents/foundation.StartupTasks-Unlock.plist"
	echo mine >"$agents/com.example.Other.plist"
	conf "[One]" "command true" "trigger TerminalOpen"
	LOADED=1 run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -e "$agent" ]
	[ ! -e "$agents/foundation.StartupTasks-Unlock.plist" ]
	[ -e "$agents/com.example.Other.plist" ]
	launchctl_calls | grep -qx "launchctl bootout gui/$(id -u)/foundation.StartupTasks-SignIn"
	launchctl_calls | grep -qx "launchctl bootout gui/$(id -u)/foundation.StartupTasks-Unlock"
	# Not loaded: removed without a bootout.
	: >"$BATS_TEST_TMPDIR/tool.log"
	echo old >"$agent"
	run "${BASH:-bash}" "$cmd"
	[ ! -e "$agent" ]
	[ -z "$(launchctl_calls)" ]
}

@test "--remove removes every startup agent, whatever startup.conf says" {
	conf "[One]" "command true" "trigger SignIn"
	run "${BASH:-bash}" "$cmd"
	[ -f "$agent" ]
	run "${BASH:-bash}" "$cmd" --remove
	[ "$status" -eq 0 ]
	[ ! -e "$agent" ]
	run "${BASH:-bash}" "$cmd" --remove
	[ "$status" -eq 0 ]
	[[ $output == *"up to date"* ]]
}

@test "an unknown argument is an error and changes nothing" {
	conf "[One]" "command true" "trigger SignIn"
	run "${BASH:-bash}" "$cmd" --nope
	[ "$status" -ne 0 ]
	[ ! -e "$agents" ]
}
