#!/usr/bin/env bats
# Open-VSCodeWorkspace against the platform stand-ins: a name opens DIRECTORY/NAME.code-workspace
# (case-insensitive, or its menu number), one already open as "NAME (Workspace)" is skipped, the menu picks names, and
# a missing folder, an empty folder or an unknown name fails.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	copy_fixture_config
	dir=$BATS_TEST_TMPDIR/workspaces
	mkdir -p "$dir"
	touch "$dir/Sample.code-workspace" "$dir/Other.code-workspace" "$dir/notes.txt"
	printf 'directory %s\n' "$dir" >"$FOUNDATION_CONFIG_DIR/vscode-workspaces.conf"
	cmd=$UNIX_DIR/modules/Application/bin/Open-VSCodeWorkspace
}

code_calls() {
	grep -c '^code ' "$STUB_LOG" || true
}

@test "a name opens its .code-workspace, matched case-insensitively" {
	run "${BASH:-bash}" "$cmd" sample --vscode-workspace
	[ "$status" -eq 0 ]
	stub_called "^code -n $dir/Sample\.code-workspace$"
	[ "$(code_calls)" -eq 1 ]
}

@test "a number names that entry of the menu (Other, Sample), as -VSCodeWorkspace 2 does on Windows" {
	run "${BASH:-bash}" "$cmd" 2
	[ "$status" -eq 0 ]
	stub_called "^code -n $dir/Sample\.code-workspace$"
	[ "$(code_calls)" -eq 1 ]
}

@test "a workspace already open in VS Code is skipped" {
	stub_window 60 com.microsoft.VSCode 1 Code "main.ts - Sample (Workspace) - Visual Studio Code"
	run "${BASH:-bash}" "$cmd" Sample Other
	[ "$status" -eq 0 ]
	! stub_called 'Sample\.code-workspace' || false
	stub_called "^code -n $dir/Other\.code-workspace$"
}

@test "a folder window named like the workspace does not count as the workspace" {
	stub_window 60 com.microsoft.VSCode 1 Code "main.ts - Sample - Visual Studio Code"
	run "${BASH:-bash}" "$cmd" Sample
	[ "$status" -eq 0 ]
	stub_called "^code -n $dir/Sample\.code-workspace$"
}

@test "an unknown name fails, the other names still open" {
	run "${BASH:-bash}" "$cmd" NoSuchWorkspaceAnywhere Other
	[ "$status" -eq 1 ]
	[ "$(code_calls)" -eq 1 ]
	stub_called "^code -n $dir/Other\.code-workspace$"
}

@test "the menu opens the chosen workspaces" {
	printf 'other sample\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(code_calls)" -eq 2 ]
}

@test "without a name and without a terminal nothing opens" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[ "$(code_calls)" -eq 0 ]
}

@test "without vscode-workspaces.conf the folder is DOTFILES_ROOT/VSCode/Workspaces" {
	rm "$FOUNDATION_CONFIG_DIR/vscode-workspaces.conf"
	root=$BATS_TEST_TMPDIR/root
	mkdir -p "$root/VSCode/Workspaces"
	touch "$root/VSCode/Workspaces/Main.code-workspace"
	DOTFILES_ROOT=$root run "${BASH:-bash}" "$cmd" Main
	[ "$status" -eq 0 ]
	stub_called "^code -n $root/VSCode/Workspaces/Main\.code-workspace$"
}

@test "a missing or empty workspaces folder fails" {
	printf 'directory %s/nope\n' "$BATS_TEST_TMPDIR" >"$FOUNDATION_CONFIG_DIR/vscode-workspaces.conf"
	run "${BASH:-bash}" "$cmd" Sample
	[ "$status" -eq 1 ]
	mkdir -p "$BATS_TEST_TMPDIR/empty"
	printf 'directory %s/empty\n' "$BATS_TEST_TMPDIR" >"$FOUNDATION_CONFIG_DIR/vscode-workspaces.conf"
	run "${BASH:-bash}" "$cmd" Sample
	[ "$status" -eq 1 ]
	[ "$(code_calls)" -eq 0 ]
}

@test "a comma list names several workspaces; an unknown flag opens nothing" {
	run "${BASH:-bash}" "$cmd" Sample,Other
	[ "$status" -eq 0 ]
	stub_called "^code -n $dir/Sample\.code-workspace$"
	stub_called "^code -n $dir/Other\.code-workspace$"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Sample --bogus
	[ "$status" -eq 1 ]
	[ "$(code_calls)" -eq 0 ]
}

@test "a failed code launch is reported and fails the run, the other names still open" {
	printf '#!/bin/sh\necho "code $*" >>"$STUB_LOG"\ncase "$*" in *Sample*) exit 1 ;; esac\nexit 0\n' >"$STUB_BIN/code"
	run "${BASH:-bash}" "$cmd" Sample Other
	[ "$status" -eq 1 ]
	[[ $output == *"could not open workspace [Sample]"* ]]
	stub_called "^code -n $dir/Other\.code-workspace$"
}

@test "without AeroSpace an open workspace is still found through System Events and skipped" {
	printf '#!/bin/sh\necho "aerospace $*" >>"$STUB_LOG"\nexit 1\n' >"$STUB_BIN/aerospace"
	stub_window 60 com.microsoft.VSCode 1 Code "main.ts - Sample (Workspace) - Visual Studio Code"
	run "${BASH:-bash}" "$cmd" Sample Other
	[ "$status" -eq 0 ]
	! stub_called 'Sample\.code-workspace' || false
	stub_called "^code -n $dir/Other\.code-workspace$"
}
