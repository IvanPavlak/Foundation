#!/usr/bin/env bats
# Open-Obsidian against stub obsidian / pgrep / open: which workspace resolves, the cold start
# waits for the CLI (queued until the layout inside a workspace open), a refusal is reported and
# never claimed as loaded.

load ../../helpers

setup() {
	setup_foundation
	export OBSIDIAN_DIRECTORY="$BATS_TEST_TMPDIR/vault"
	mkdir -p "$OBSIDIAN_DIRECTORY/.obsidian" "$BATS_TEST_TMPDIR/bin"
	printf '{"workspaces":{"Server":{},"Notes":{}},"active":"Notes"}' >"$OBSIDIAN_DIRECTORY/.obsidian/workspaces.json"
	log=$BATS_TEST_TMPDIR/calls
	: >"$log"
	stub() {
		printf '#!/bin/sh\n%s\n' "$2" >"$BATS_TEST_TMPDIR/bin/$1"
		chmod +x "$BATS_TEST_TMPDIR/bin/$1"
	}
	stub obsidian "echo \"obsidian \$*\" >>$log; case \"\$*\" in *workspace:load*) echo \"\${OBSIDIAN_ANSWER:-Loaded}\" ;; *) echo ok ;; esac"
	stub open "echo \"open \$*\" >>$log"
	stub pgrep "exit \${OBSIDIAN_RUNNING:-1}"
	export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
	cmd=$UNIX_DIR/modules/Application/bin/Open-Obsidian
}

@test "--workspace on a cold start: starts Obsidian detached, waits for the CLI, loads" {
	run "${BASH:-bash}" "$cmd" --workspace server </dev/null
	[ "$status" -eq 0 ]
	grep -q '^open -g obsidian://open?vault=vault' "$log"
	grep -q '^obsidian vault=vault workspaces' "$log"
	grep -q '^obsidian vault=vault workspace:load name=server' "$log"
}

@test "during a workspace open the same-named Obsidian workspace is loaded, no menu" {
	OBSIDIAN_RUNNING=0 FOUNDATION_WORKSPACE_OPEN=1 FOUNDATION_CURRENT_WORKSPACE=server run "${BASH:-bash}" "$cmd" </dev/null
	[ "$status" -eq 0 ]
	grep -q 'workspace:load name=Server' "$log"
	! grep -q '^open' "$log" || false
}

@test "running and no workspace resolves: Obsidian is left alone" {
	OBSIDIAN_RUNNING=0 FOUNDATION_WORKSPACE_OPEN=1 FOUNDATION_CURRENT_WORKSPACE=Dotfiles run "${BASH:-bash}" "$cmd" </dev/null
	[ "$status" -eq 0 ]
	[ ! -s "$log" ]
}

@test "a CLI refusal is reported, not claimed" {
	OBSIDIAN_RUNNING=0 OBSIDIAN_ANSWER="Command line interface is not enabled" run "${BASH:-bash}" "$cmd" --workspace Notes </dev/null
	[ "$status" -eq 1 ]
	[[ $output == *"Enable-ObsidianCli"* ]]
	[[ $output != *"loaded!"* ]]
}

@test "a bare NAME is the workspace, as Windows' positional -Workspace" {
	OBSIDIAN_RUNNING=0 run "${BASH:-bash}" "$cmd" Notes </dev/null
	[ "$status" -eq 0 ]
	grep -q 'workspace:load name=Notes' "$log"
}

@test "--current-workspace NAME loads the same-named Obsidian workspace, as Windows' -CurrentWorkspace" {
	OBSIDIAN_RUNNING=0 FOUNDATION_CURRENT_WORKSPACE=Dotfiles run "${BASH:-bash}" "$cmd" --current-workspace server </dev/null
	[ "$status" -eq 0 ]
	grep -q 'workspace:load name=Server' "$log"
	: >"$log"
	# A name the vault has no Obsidian workspace of loads nothing.
	OBSIDIAN_RUNNING=0 run "${BASH:-bash}" "$cmd" --current-workspace Dotfiles </dev/null
	[ "$status" -eq 0 ]
	[ ! -s "$log" ]
}

@test "inside a workspace open the load is queued, and the flush before the layout runs it" {
	export FOUNDATION_RUN_DIR=$BATS_TEST_TMPDIR/run
	mkdir -p "$FOUNDATION_RUN_DIR"
	OBSIDIAN_RUNNING=0 FOUNDATION_WORKSPACE_OPEN=1 FOUNDATION_CURRENT_WORKSPACE=server run "${BASH:-bash}" "$cmd" </dev/null
	[ "$status" -eq 0 ]
	[[ $output == *"loads before the layout"* ]]
	! grep -q 'workspace:load' "$log" || false
	grep -q $'^Obsidian workspace Server\tOpen-Obsidian --load-only --workspace Server' "$FOUNDATION_RUN_DIR/deferred-actions"
	run foundation_flush_deferred
	[ "$status" -eq 0 ]
	grep -q '^obsidian vault=vault workspace:load name=Server' "$log"
	[ ! -s "$FOUNDATION_RUN_DIR/deferred-actions" ]
}

@test "a queued load that fails makes the flush fail with its label" {
	export FOUNDATION_RUN_DIR=$BATS_TEST_TMPDIR/run
	mkdir -p "$FOUNDATION_RUN_DIR"
	foundation_defer "Obsidian workspace Server" Open-Obsidian --load-only --workspace Server
	OBSIDIAN_ANSWER='Error: no such workspace' run foundation_flush_deferred
	[ "$status" -eq 1 ]
	[[ $output == *"Deferred action [Obsidian workspace Server] failed"* ]]
}

@test "default-workspace loads on a cold start only; a running Obsidian ignores it" {
	use_empty_config
	printf 'default-workspace Notes\n' >"$FOUNDATION_CONFIG_DIR/obsidian.conf"
	run "${BASH:-bash}" "$cmd" </dev/null
	[ "$status" -eq 0 ]
	grep -q 'workspace:load name=Notes' "$log"
	: >"$log"
	OBSIDIAN_RUNNING=0 run "${BASH:-bash}" "$cmd" </dev/null
	[ "$status" -eq 0 ]
	[[ $output == *"already running"* ]]
	[ ! -s "$log" ]
}

@test "a CLI that never reaches Obsidian ends the wait with exit 1 and no load" {
	stub obsidian "echo \"obsidian \$*\" >>$log; echo 'The CLI is unable to find Obsidian'"
	FOUNDATION_OBSIDIAN_CLI_WAIT=1 run "${BASH:-bash}" "$cmd" --workspace Notes </dev/null
	[ "$status" -eq 1 ]
	[[ $output == *"did not answer within 1 s"* ]]
	! grep -q 'workspace:load' "$log" || false
}

@test "a hung CLI is killed at the wait's deadline instead of stalling the open" {
	stub obsidian "echo \"obsidian \$*\" >>$log; exec sleep 30"
	SECONDS=0
	FOUNDATION_OBSIDIAN_CLI_WAIT=1 run "${BASH:-bash}" "$cmd" --workspace Notes </dev/null
	[ "$status" -eq 1 ]
	[ "$SECONDS" -lt 10 ]
	! grep -q 'workspace:load' "$log" || false
}

@test "an unknown workspace warns and is still tried; the CLI's 'No workspace' refusal fails" {
	OBSIDIAN_RUNNING=0 run "${BASH:-bash}" "$cmd" --workspace Nope </dev/null
	[ "$status" -eq 0 ]
	[[ $output == *"no saved workspace [Nope] - trying the load anyway"* ]]
	grep -q 'workspace:load name=Nope' "$log"
	OBSIDIAN_RUNNING=0 OBSIDIAN_ANSWER='No workspace named Nope' run "${BASH:-bash}" "$cmd" --workspace Nope </dev/null
	[ "$status" -eq 1 ]
	[[ $output == *"No workspace named Nope"* ]]
	[[ $output != *"loaded!"* ]]
}

@test "a vault name with a space is URI-encoded" {
	export OBSIDIAN_DIRECTORY="$BATS_TEST_TMPDIR/My Vault"
	mkdir -p "$OBSIDIAN_DIRECTORY"
	run "${BASH:-bash}" "$cmd" </dev/null
	[ "$status" -eq 0 ]
	grep -q '^open -g obsidian://open?vault=My%20Vault$' "$log"
}

@test "an unparseable workspaces.json lists no workspace and shows no menu" {
	printf 'not json' >"$OBSIDIAN_DIRECTORY/.obsidian/workspaces.json"
	printf 'Notes\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd" </dev/null
	[ "$status" -eq 0 ]
	[[ $output != *"[Obsidian Workspaces]"* ]]
	! grep -q 'workspace:load' "$log" || false
}

@test "a bare call from a terminal offers the saved workspaces and loads the choice" {
	printf 'Notes\n' >"$BATS_TEST_TMPDIR/answers"
	OBSIDIAN_RUNNING=0 FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd" </dev/null
	[ "$status" -eq 0 ]
	[[ $output == *"[Obsidian Workspaces]"* ]]
	grep -q 'workspace:load name=Notes' "$log"
}

@test "without the CLI the registration hint is printed and Obsidian still counts as opened" {
	export FOUNDATION_RUN_DIR=$BATS_TEST_TMPDIR/run
	mkdir -p "$FOUNDATION_RUN_DIR"
	FOUNDATION_OBSIDIAN_CLI=$BATS_TEST_TMPDIR/no-obsidian-cli FOUNDATION_WORKSPACE_OPEN=1 FOUNDATION_CURRENT_WORKSPACE=Server run "${BASH:-bash}" "$cmd" </dev/null
	[ "$status" -eq 0 ]
	[[ $output == *"CLI was not found"* ]]
	[[ $output == *"Obsidian opened!"* ]]
	grep -q '^open -g obsidian://open?vault=vault' "$log"
	[ ! -s "$FOUNDATION_RUN_DIR/deferred-actions" ]
}

@test "no vault configured is an error and opens nothing" {
	use_empty_config
	unset OBSIDIAN_DIRECTORY
	run "${BASH:-bash}" "$cmd" --workspace Notes </dev/null
	[ "$status" -eq 1 ]
	[[ $output == *"No Obsidian vault configured"* ]]
	[ ! -s "$log" ]
}
