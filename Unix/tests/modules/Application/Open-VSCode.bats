#!/usr/bin/env bats
# Open-VSCode against the platform stand-ins (`code -n DIR` opens a Code window titled after the
# folder): one window per vscode-folders.conf name or menu number, a folder already open as a
# whole title segment is skipped, --default opens VS Code bare, the menu picks folders, the last
# line of a name wins,
# and a workspace override reroutes to Open-VSCodeWorkspace.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	copy_fixture_config
	work=$BATS_TEST_TMPDIR/work
	mkdir -p "$work/alpha" "$work/beta" "$BATS_TEST_TMPDIR/workspaces"
	printf 'Alpha %s/alpha\nBeta  %s/beta\nGone  %s/nope\n' "$work" "$work" "$work" >"$FOUNDATION_CONFIG_DIR/vscode-folders.conf"
	touch "$BATS_TEST_TMPDIR/workspaces/Sample.code-workspace"
	printf 'directory %s/workspaces\n' "$BATS_TEST_TMPDIR" >"$FOUNDATION_CONFIG_DIR/vscode-workspaces.conf"
	cmd=$UNIX_DIR/modules/Application/bin/Open-VSCode
}

answers() {
	printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/answers"
	export FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers
}

code_calls() {
	grep -c '^code ' "$STUB_LOG" || true
}

@test "named folders open one window each, matched case-insensitively, and a rerun skips them" {
	run "${BASH:-bash}" "$cmd" alpha Beta
	[ "$status" -eq 0 ]
	stub_called "^code -n $work/alpha$"
	stub_called "^code -n $work/beta$"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Alpha --folder beta
	[ "$status" -eq 0 ]
	[ "$(code_calls)" -eq 0 ]
}

@test "a number names that entry of the menu, as -Folder 2 does on Windows" {
	run "${BASH:-bash}" "$cmd" 2
	[ "$status" -eq 0 ]
	stub_called "^code -n $work/beta$"
	[ "$(code_calls)" -eq 1 ]
}

@test "only a whole title segment counts as open" {
	stub_window 60 com.microsoft.VSCode 1 Code "main.ts - alpha-ui - Visual Studio Code"
	run "${BASH:-bash}" "$cmd" Alpha
	stub_called "^code -n $work/alpha$"
	: >"$STUB_LOG"
	stub_window 61 com.microsoft.VSCode 1 Code "main.ts - beta - Visual Studio Code"
	run "${BASH:-bash}" "$cmd" Beta
	[ "$status" -eq 0 ]
	[ "$(code_calls)" -eq 0 ]
}

@test "an unknown folder or a missing directory fails, the other folders still open" {
	run "${BASH:-bash}" "$cmd" NoSuchFolderAnywhere Gone Beta
	[ "$status" -eq 1 ]
	[ "$(code_calls)" -eq 1 ]
	stub_called "^code -n $work/beta$"
}

@test "--default skips the menu and opens VS Code itself, as the Windows -Default" {
	run "${BASH:-bash}" "$cmd" --default </dev/null
	[ "$status" -eq 0 ]
	stub_called "^code -n$"
	! stub_called "^code -n $work/alpha$" || false
	[ "$(code_calls)" -eq 1 ]
}

@test "the menu opens the chosen folders" {
	answers '2'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called "^code -n $work/beta$"
	[ "$(code_calls)" -eq 1 ]
}

@test "an empty Enter opens VS Code itself, unless a VS Code window exists" {
	answers ''
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^code -n$'
	: >"$STUB_LOG"
	stub_window 60 com.microsoft.VSCode 1 Code "Welcome - Visual Studio Code"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(code_calls)" -eq 0 ]
}

@test "without a folder and without a terminal nothing opens" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[ "$(code_calls)" -eq 0 ]
}

@test "fails without a vscode-folders.conf" {
	rm "$FOUNDATION_CONFIG_DIR/vscode-folders.conf"
	run "${BASH:-bash}" "$cmd" Alpha
	[ "$status" -eq 1 ]
	[ "$(code_calls)" -eq 0 ]
}

@test "a VS Code workspace override opens that workspace instead of a folder" {
	FOUNDATION_VSCODE_WORKSPACE=sample run "${BASH:-bash}" "$cmd" Alpha
	[ "$status" -eq 0 ]
	stub_called "^code -n $BATS_TEST_TMPDIR/workspaces/Sample\.code-workspace$"
	[ "$(code_calls)" -eq 1 ]
}

@test "the override '?' shows the workspace menu" {
	answers 'Sample'
	FOUNDATION_VSCODE_WORKSPACE='?' run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called "^code -n $BATS_TEST_TMPDIR/workspaces/Sample\.code-workspace$"
}

@test "the last line of a name wins, so an overlay line overrides the base one, and the menu lists it once" {
	printf 'alpha %s/beta\n' "$work" >"$FOUNDATION_CONFIG_DIR/vscode-folders.local.conf"
	run "${BASH:-bash}" "$cmd" --folder Alpha
	[ "$status" -eq 0 ]
	stub_called "^code -n $work/beta$"
	! stub_called "^code -n $work/alpha$" || false
	: >"$STUB_LOG"
	: >"$STUB_WINDOWS"
	answers '1'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(printf '%s\n' "$output" | grep -ciE '[] ]alpha$')" -eq 1 ]
	stub_called "^code -n $work/beta$"
}

@test "a comma list names several folders, as -Folder Alpha, Beta does; an unknown flag opens nothing" {
	run "${BASH:-bash}" "$cmd" -Folder Alpha, Beta
	[ "$status" -eq 0 ]
	stub_called "^code -n $work/alpha$"
	stub_called "^code -n $work/beta$"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Alpha --defualt
	[ "$status" -eq 1 ]
	[ "$(code_calls)" -eq 0 ]
}

# AeroSpace not answering: its CLI fails, as when the app is not running.
no_aerospace() {
	printf '#!/bin/sh\necho "aerospace $*" >>"$STUB_LOG"\nexit 1\n' >"$STUB_BIN/aerospace"
}

@test "without AeroSpace an open folder is still found through System Events and skipped" {
	no_aerospace
	stub_window 60 com.microsoft.VSCode 1 Code "main.ts - alpha - Visual Studio Code"
	run "${BASH:-bash}" "$cmd" Alpha Beta
	[ "$status" -eq 0 ]
	[[ $output == *"[Alpha] is already open"* ]]
	! stub_called "^code -n $work/alpha$" || false
	stub_called "^code -n $work/beta$"
}

@test "without AeroSpace a running VS Code with no window is not launched again" {
	no_aerospace
	echo com.microsoft.VSCode >"$STUB_RUNNING"
	run "${BASH:-bash}" "$cmd" --default
	[ "$status" -eq 0 ]
	[[ $output == *"already running"* ]]
	[ "$(code_calls)" -eq 0 ]
}

@test "a failed code launch is reported and fails the run, the other folders still open" {
	printf '#!/bin/sh\necho "code $*" >>"$STUB_LOG"\ncase "$*" in *alpha*) exit 1 ;; esac\nexit 0\n' >"$STUB_BIN/code"
	run "${BASH:-bash}" "$cmd" Alpha Beta
	[ "$status" -eq 1 ]
	[[ $output == *"could not open [Alpha]"* ]]
	stub_called "^code -n $work/beta$"
}
