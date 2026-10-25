#!/usr/bin/env bats
# Open-Project against the stand-ins: the project's actions run in order - here Open-VSCode on
# its folder and Open-ProjectTerminals for its tabs; a menu number names a project, an unknown
# project fails; --run-app, --new-window, --alongside and --vscode-workspace reach the actions they
# are for; {ProjectName} in an action line is the project.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	stub_config
	mkdir -p "$BATS_TEST_TMPDIR/demo"
	printf '\n[Demo]\npath ROOT %s/demo\naction Open-VSCode Demo\naction Open-ProjectTerminals Demo\ntab ROOT\n' "$BATS_TEST_TMPDIR" >>"$FOUNDATION_CONFIG_DIR/projects.conf"
	printf 'Demo %s/demo\n' "$BATS_TEST_TMPDIR" >>"$FOUNDATION_CONFIG_DIR/vscode-folders.conf"
	cmd=$UNIX_DIR/modules/Workflow/bin/Open-Project
}

@test "actions run in order: VS Code on the folder, then the project tabs" {
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called "^code -n $BATS_TEST_TMPDIR/demo"
	stub_called 'set-tab-title --pane-id 700 Demo\.ROOT'
	code_line=$(grep -n '^code -n' "$STUB_LOG" | cut -d: -f1)
	tab_line=$(grep -n 'set-tab-title' "$STUB_LOG" | head -1 | cut -d: -f1)
	[ "$code_line" -lt "$tab_line" ]
}

@test "a number names that entry of the menu, as -Project 2 does on Windows" {
	foundation_load config project
	n=$(project_names | grep -nx Demo | cut -d: -f1)
	run "${BASH:-bash}" "$cmd" "$n"
	[ "$status" -eq 0 ]
	stub_called "^code -n $BATS_TEST_TMPDIR/demo"
	stub_called 'set-tab-title --pane-id 700 Demo\.ROOT'
}

@test "an unknown project fails without launching anything" {
	run "${BASH:-bash}" "$cmd" NoSuchProjectAnywhere
	[ "$status" -ne 0 ]
	! stub_called '^code' || false
}

@test "a comma list names several projects; an unknown flag launches nothing" {
	run "${BASH:-bash}" "$cmd" Demo,NoSuchProjectAnywhere
	[ "$status" -ne 0 ]
	stub_called "^code -n $BATS_TEST_TMPDIR/demo"
	[[ $output == *"[NoSuchProjectAnywhere]"* ]]
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Demo --run-ap
	[ "$status" -eq 1 ]
	[[ $output == *"Unknown argument => --run-ap"* ]]
	! stub_called '^code' || false
}

# One WezTerm window (3) holding this shell's pane 5 and no project tab: Open-ProjectTerminals and
# Run-Project open into it unless told to open a new window.
own_window() {
	echo '[{"window_id":3,"tab_id":9,"pane_id":5,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys005"}]' >"$STUB_PANES"
	export WEZTERM_PANE=5 STUB_TTY=ttys005
}

@test "--run-app opens the tabs with Run-Project, which types the run commands" {
	printf 'run ROOT npm start\n' >>"$FOUNDATION_CONFIG_DIR/projects.conf"
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	! stub_called 'no-paste npm start' || false
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Demo --run-app
	[ "$status" -eq 0 ]
	stub_called 'send-text --pane-id 700 --no-paste npm start'
}

@test "--new-window reaches Open-ProjectTerminals, and Run-Project with --run-app" {
	printf 'run ROOT npm start\n' >>"$FOUNDATION_CONFIG_DIR/projects.conf"
	own_window
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called 'spawn --window-id 3 '
	! stub_called 'spawn --new-window' || false
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Demo --new-window
	stub_called 'spawn --new-window'
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Demo --run-app --new-window
	stub_called 'spawn --new-window'
	stub_called 'no-paste npm start'
}

@test "--alongside reaches Open-ProjectTerminals: its tabs open even when they are open already" {
	echo '[{"window_id":3,"tab_id":9,"pane_id":5,"is_active":true,"tab_title":"Demo.ROOT","title":"zsh","cwd":"file:///x"}]' >"$STUB_PANES"
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	! stub_called 'spawn' || false
	run "${BASH:-bash}" "$cmd" Demo --alongside
	[ "$status" -eq 0 ]
	stub_called 'set-tab-title --pane-id 700 Demo\.ROOT'
}

@test "without a project the menu's pick is opened" {
	printf 'Demo\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called "^code -n $BATS_TEST_TMPDIR/demo"
	stub_called 'set-tab-title --pane-id 700 Demo\.ROOT'
}

@test "--vscode-workspace NAME opens that VS Code workspace in place of the project folder" {
	mkdir -p "$BATS_TEST_TMPDIR/workspaces"
	touch "$BATS_TEST_TMPDIR/workspaces/MyWorkspace.code-workspace"
	printf 'directory %s/workspaces\n' "$BATS_TEST_TMPDIR" >"$FOUNDATION_CONFIG_DIR/vscode-workspaces.conf"
	run "${BASH:-bash}" "$cmd" Demo --vscode-workspace MyWorkspace
	[ "$status" -eq 0 ]
	stub_called "^code -n $BATS_TEST_TMPDIR/workspaces/MyWorkspace\.code-workspace$"
	! stub_called "^code -n $BATS_TEST_TMPDIR/demo$" || false
	# The terminal tabs still open as configured.
	stub_called 'set-tab-title --pane-id 700 Demo\.ROOT'
}

@test "{ProjectName} in an action line is the project being opened, by its configured name" {
	printf '\n[Named]\npath ROOT %s/demo\naction Open-ProjectTerminals {ProjectName}\ntab ROOT\n' "$BATS_TEST_TMPDIR" >>"$FOUNDATION_CONFIG_DIR/projects.conf"
	run "${BASH:-bash}" "$cmd" named
	[ "$status" -eq 0 ]
	stub_called 'set-tab-title --pane-id 700 Named\.ROOT'
	[[ $output != *"{ProjectName}"* ]]
}
