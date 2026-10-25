#!/usr/bin/env bats
# Close-Workspace (cw) against the platform stand-ins: it closes exactly what the record owns -
# an app whose every window is owned is quit, a shared app only loses its owned windows, and an
# unrecorded workspace is left alone; a workspace is named, or numbered as in the menu.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	stub_window 100 com.github.wez.wezterm 1 WezTerm "[1/1] zsh"
	stub_window 200 com.microsoft.VSCode 1 Code "Dotfiles"
	stub_window 300 org.mozilla.firefox 2 Firefox "Owned tab"
	stub_window 301 org.mozilla.firefox 2 Firefox "Not owned"
	printf 'Demo\twindow\t200\tCode\tcom.microsoft.VSCode\tDotfiles\nDemo\twindow\t300\tFirefox\torg.mozilla.firefox\tOwned tab\n' >"$FOUNDATION_STATE_DIR/open-workspaces"
	cmd=$UNIX_DIR/modules/Workflow/bin/Close-Workspace
}

@test "a fully owned app is quit, a shared app only loses its owned window, the record is cleared" {
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called 'quit app id "com\.microsoft\.VSCode"'
	! stub_called 'quit app id "org\.mozilla\.firefox"' || false
	stub_called '^aerospace close --window-id 300'
	! stub_called '^aerospace close --window-id 301' || false
	! stub_called 'com\.github\.wez\.wezterm"' || false
	[ -z "$(grep '^Demo' "$FOUNDATION_STATE_DIR/open-workspaces")" ]
}

@test "a number given as a name closes that entry of the menu, as -Workspace 1 does on Windows" {
	run "${BASH:-bash}" "$cmd" 2
	[ "$status" -eq 0 ]
	[[ $output == *"[2] is not tracked"* ]]
	! stub_called 'quit app id' || false
	run "${BASH:-bash}" "$cmd" 1
	[ "$status" -eq 0 ]
	stub_called 'quit app id "com\.microsoft\.VSCode"'
	[ -z "$(grep '^Demo' "$FOUNDATION_STATE_DIR/open-workspaces")" ]
}

@test "a workspace without a record is reported and nothing is closed" {
	run "${BASH:-bash}" "$cmd" Elsewhere
	! stub_called 'quit app id' || false
	! stub_called '^aerospace close' || false
}

@test "a comma list names several workspaces; an unknown flag closes nothing" {
	run "${BASH:-bash}" "$cmd" -Workspace Elsewhere,Demo
	[ "$status" -eq 0 ]
	stub_called 'quit app id "com\.microsoft\.VSCode"'
	[[ $output == *"[Elsewhere] is not tracked"* ]]
	: >"$STUB_LOG"
	printf 'Demo\twindow\t200\tCode\tcom.microsoft.VSCode\tDotfiles\n' >"$FOUNDATION_STATE_DIR/open-workspaces"
	run "${BASH:-bash}" "$cmd" Demo --al
	[ "$status" -eq 1 ]
	! stub_called 'quit app id' || false
}

@test "an app that ignores the quit is reported and left running, never killed" {
	echo com.microsoft.VSCode >"$BATS_TEST_TMPDIR/ignores-quit"
	FOUNDATION_QUIT_WAIT_SECONDS=0 run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	[ "$(grep -c 'quit app id "com\.microsoft\.VSCode"' "$STUB_LOG")" -eq 1 ]
	[[ $output == *"Code did not quit - leaving it alone (it may be waiting on unsaved work)"* ]]
	[[ $output == *"Closed Demo (0 app(s) quit, 1 window(s) closed"* ]]
	grep -qxF com.microsoft.VSCode "$STUB_RUNNING"
}

@test "nothing tracked: a warning and no platform call that closes anything" {
	: >"$FOUNDATION_STATE_DIR/open-workspaces"
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	[[ $output == *"No open workspace is tracked"* ]]
	! stub_called 'quit app id' || false
	! stub_called '^aerospace close' || false
}

@test "--all closes every tracked workspace, each its own windows" {
	printf 'Other\twindow\t301\tFirefox\torg.mozilla.firefox\tNot owned\n' >>"$FOUNDATION_STATE_DIR/open-workspaces"
	run "${BASH:-bash}" "$cmd" --all
	[ "$status" -eq 0 ]
	stub_called 'quit app id "com\.microsoft\.VSCode"'
	stub_called '^aerospace close --window-id 300'
	# Once Demo closed its Firefox window, Other owns the last one: Firefox is quit.
	stub_called 'quit app id "org\.mozilla\.firefox"'
	[ ! -s "$FOUNDATION_STATE_DIR/open-workspaces" ]
}

@test "the menu: an empty Enter closes nothing, a number closes that workspace" {
	printf '\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	! stub_called 'quit app id' || false
	grep -q '^Demo' "$FOUNDATION_STATE_DIR/open-workspaces"
	printf '1\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called 'quit app id "com\.microsoft\.VSCode"'
}

@test "another workspace's record survives; a terminal-only workspace quits nothing" {
	printf 'Term\twindow\t100\tWezTerm\tcom.github.wez.wezterm\t[1/1] zsh\n' >>"$FOUNDATION_STATE_DIR/open-workspaces"
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	grep -qxF $'Term\twindow\t100\tWezTerm\tcom.github.wez.wezterm\t[1/1] zsh' "$FOUNDATION_STATE_DIR/open-workspaces"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Term
	[ "$status" -eq 0 ]
	! stub_called 'quit app id' || false
	! stub_called '^aerospace close' || false
}

@test "an owned window that is gone, with no window of its app left, is skipped" {
	printf 'Gone\twindow\t260\tSlack\tcom.tinyspeck.slackmacgap\tSlack\n' >"$FOUNDATION_STATE_DIR/open-workspaces"
	run "${BASH:-bash}" "$cmd" Gone
	[ "$status" -eq 0 ]
	! stub_called 'quit app id' || false
	! stub_called '^aerospace close' || false
	[[ $output == *"Closed Gone (0 app(s) quit, 0 window(s) closed, 0 tab(s) closed)!"* ]]
}

@test "a recreated window is found by its app, a restarted one by app and title, never another's" {
	# Code window 250 is gone, the app's one live window is 200: recreated, so Code is quit.
	printf 'Re\twindow\t250\tCode\tcom.microsoft.VSCode\tOld title\n' >"$FOUNDATION_STATE_DIR/open-workspaces"
	run "${BASH:-bash}" "$cmd" Re
	stub_called 'quit app id "com\.microsoft\.VSCode"'
	# Firefox window 399 is gone and Firefox has two windows: the one with its exact title closes.
	printf 'Re\twindow\t399\tFirefox\torg.mozilla.firefox\tNot owned\n' >"$FOUNDATION_STATE_DIR/open-workspaces"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Re
	stub_called '^aerospace close --window-id 301'
	! stub_called '^aerospace close --window-id 300' || false
	# The same title, but window 301 belongs to another open workspace: left alone.
	stub_window 301 org.mozilla.firefox 2 Firefox "Not owned"
	printf 'Re\twindow\t399\tFirefox\torg.mozilla.firefox\tNot owned\nOther\twindow\t301\tFirefox\torg.mozilla.firefox\tNot owned\n' >"$FOUNDATION_STATE_DIR/open-workspaces"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Re
	! stub_called '^aerospace close' || false
}

@test "owned tabs close, a gone one is skipped, the tab cw runs in closes last; focus returns" {
	command -v jq >/dev/null 2>&1 || skip "jq is required by the WezTerm driver"
	echo '[{"window_id":1,"tab_id":2,"pane_id":5,"is_active":true,"tab_title":"Demo.ROOT","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys005"},{"window_id":1,"tab_id":3,"pane_id":6,"is_active":false,"tab_title":"Demo.API","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys006"}]' >"$STUB_PANES"
	export WEZTERM_PANE=5 STUB_TTY=ttys005
	printf 'Demo\tpane\t5\tDemo.ROOT\nDemo\tpane\t6\tDemo.API\nDemo\tpane\t9\tDemo.GONE\n' >>"$FOUNDATION_STATE_DIR/open-workspaces"
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	[[ $output == *"2 tab(s) closed)!"* ]]
	stub_called 'kill-pane --pane-id 6$'
	! stub_called 'kill-pane --pane-id 9$' || false
	stub_called '^aerospace focus --window-id 100$'
	stub_wait_for 'kill-pane --pane-id 5$'
	[ "$(sed -n 's/.*kill-pane --pane-id \([0-9]*\)$/\1/p' "$STUB_LOG" | tr '\n' ' ')" = "6 5 " ]
}

@test "the tab cw runs in survives when the workspace does not own it" {
	command -v jq >/dev/null 2>&1 || skip "jq is required by the WezTerm driver"
	echo '[{"window_id":1,"tab_id":2,"pane_id":5,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys005"}]' >"$STUB_PANES"
	export WEZTERM_PANE=5 STUB_TTY=ttys005
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	sleep 1
	! stub_called 'kill-pane' || false
	stub_called '^aerospace focus --window-id 100$'
}

@test "a workspace open twice: the menu labels each instance, a label closes one, a name both" {
	printf 'Demo#2\twindow\t301\tFirefox\torg.mozilla.firefox\tNot owned\nDemo#2\tmeta\talongside\n' >>"$FOUNDATION_STATE_DIR/open-workspaces"
	printf '\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd"
	[[ $output == *"Demo (plain, desktop 1)"* ]]
	[[ $output == *"Demo (alongside, desktop 2)"* ]]
	run "${BASH:-bash}" "$cmd" 'demo (alongside, desktop 2)'
	[ "$status" -eq 0 ]
	stub_called '^aerospace close --window-id 301'
	! stub_called '^aerospace close --window-id 300' || false
	! grep -q '^Demo#2' "$FOUNDATION_STATE_DIR/open-workspaces" || false
	grep -q $'^Demo\twindow' "$FOUNDATION_STATE_DIR/open-workspaces"
	printf 'Demo#2\twindow\t301\tFirefox\torg.mozilla.firefox\tNot owned\n' >>"$FOUNDATION_STATE_DIR/open-workspaces"
	stub_window 301 org.mozilla.firefox 2 Firefox "Not owned"
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	[ ! -s "$FOUNDATION_STATE_DIR/open-workspaces" ]
}

@test "--dry-run (the Windows -WhatIf) lists what would close and changes nothing" {
	command -v jq >/dev/null 2>&1 || skip "jq is required by the WezTerm driver"
	echo '[{"window_id":1,"tab_id":3,"pane_id":6,"is_active":false,"tab_title":"Demo.API","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys006"}]' >"$STUB_PANES"
	printf 'Demo\tpane\t6\tDemo.API\n' >>"$FOUNDATION_STATE_DIR/open-workspaces"
	cp "$FOUNDATION_STATE_DIR/open-workspaces" "$BATS_TEST_TMPDIR/before"
	run "${BASH:-bash}" "$cmd" Demo -WhatIf
	[ "$status" -eq 0 ]
	[[ $output == *"Would quit Code"* ]]
	[[ $output == *'Would close the window "Owned tab" (Firefox)'* ]]
	[[ $output == *"Would close the tab Demo.API"* ]]
	[[ $output == *"Dry run - nothing was closed"* ]]
	! stub_called 'quit app id' || false
	! stub_called '^aerospace close' || false
	! stub_called 'kill-pane' || false
	cmp -s "$BATS_TEST_TMPDIR/before" "$FOUNDATION_STATE_DIR/open-workspaces"
}
