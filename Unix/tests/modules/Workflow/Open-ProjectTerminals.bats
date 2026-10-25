#!/usr/bin/env bats
# Open-ProjectTerminals against the WezTerm stand-in: one tab per `tab` line in its directory,
# titled <Project>.<KEY>, a project named or numbered as in the menu, tabs already open are
# skipped unless --force, an unknown project fails;
# greeting.conf onefetch-in-project-terminals (or --invoke-onefetch / --no-onefetch) decides whether
# the tabs' first greeting draws onefetch, both for a plain open and for a workspace open;
# --focus-tab picks the tab selected afterwards.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	stub_config
	mkdir -p "$BATS_TEST_TMPDIR/demo/api" "$BATS_TEST_TMPDIR/demo/ui"
	printf '\n[Demo]\npath API %s/demo/api\npath UI %s/demo/ui\ntab API\ntab UI\n' "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR" >>"$FOUNDATION_CONFIG_DIR/projects.conf"
	cmd=$UNIX_DIR/modules/Workflow/bin/Open-ProjectTerminals
}

@test "one titled tab per tab line, in its directory" {
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called "spawn .*--cwd $BATS_TEST_TMPDIR/demo/api"
	stub_called "spawn .*--cwd $BATS_TEST_TMPDIR/demo/ui"
	stub_called 'set-tab-title --pane-id 700 Demo\.API'
	stub_called 'set-tab-title --pane-id 700 Demo\.UI'
}

@test "a number names that entry of the menu of projects with tabs, as -Project 2 does on Windows" {
	foundation_load config project
	n=$(project_names | while IFS= read -r name; do [ -n "$(project_lines "$name" tab)" ] && echo "$name"; done | grep -nx Demo | cut -d: -f1)
	run "${BASH:-bash}" "$cmd" "$n"
	[ "$status" -eq 0 ]
	stub_called 'set-tab-title --pane-id 700 Demo\.API'
	stub_called 'set-tab-title --pane-id 700 Demo\.UI'
}

@test "tabs already open are skipped, --force opens them again" {
	echo '[{"window_id":1,"tab_id":1,"pane_id":5,"is_active":true,"tab_title":"Demo.API","title":"zsh","cwd":"file:///x"},{"window_id":1,"tab_id":2,"pane_id":6,"is_active":false,"tab_title":"Demo.UI","title":"zsh","cwd":"file:///x"}]' >"$STUB_PANES"
	run "${BASH:-bash}" "$cmd" Demo
	! stub_called 'spawn' || false
	run "${BASH:-bash}" "$cmd" Demo --force
	stub_called 'spawn'
}

@test "an unknown project fails" {
	run "${BASH:-bash}" "$cmd" NoSuchProjectAnywhere
	[ "$status" -ne 0 ]
	! stub_called 'spawn' || false
}

@test "from a WezTerm pane the tabs join its window and that pane is active again" {
	echo '[{"window_id":3,"tab_id":9,"pane_id":5,"is_active":true,"tab_title":"Other.X","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys005"}]' >"$STUB_PANES"
	export WEZTERM_PANE=5 STUB_TTY=ttys005
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called 'spawn --window-id 3 '
	stub_called 'activate-pane --pane-id 5$'
}

@test "an inherited WEZTERM_PANE outside its pane opens a new window and activates nothing" {
	echo '[{"window_id":3,"tab_id":9,"pane_id":5,"is_active":true,"tab_title":"Other.X","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys005"}]' >"$STUB_PANES"
	export WEZTERM_PANE=5
	unset STUB_TTY
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called 'spawn --new-window'
	! stub_called 'spawn --window-id 3 ' || false
	! stub_called 'activate-pane' || false
}

@test "onefetch-in-project-terminals on (the default) greets with onefetch" {
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called 'spawn '
	! stub_called 'FOUNDATION_STARTUP_NO_ONEFETCH' || false
}

@test "onefetch-in-project-terminals off starts the tabs' shells without onefetch, --invoke-onefetch wins" {
	echo 'onefetch-in-project-terminals off' >>"$FOUNDATION_CONFIG_DIR/greeting.conf"
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	[ "$(grep -c 'spawn .*-- /usr/bin/env FOUNDATION_STARTUP_NO_ONEFETCH=1 ' "$STUB_LOG")" -eq 2 ]
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Demo --invoke-onefetch
	stub_called 'spawn '
	! stub_called 'FOUNDATION_STARTUP_NO_ONEFETCH' || false
}

@test "--no-onefetch leaves onefetch out for one call" {
	run "${BASH:-bash}" "$cmd" Demo --no-onefetch
	[ "$status" -eq 0 ]
	[ "$(grep -c 'FOUNDATION_STARTUP_NO_ONEFETCH=1' "$STUB_LOG")" -eq 2 ]
}

@test "during a workspace open the deferred greeting skips onefetch when it is off" {
	export FOUNDATION_WORKSPACE_OPEN=1
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called 'send-text --pane-id 700 --no-paste Show-TerminalGreeting --no-resize --settle$'
	: >"$STUB_LOG"
	echo 'onefetch-in-project-terminals off' >>"$FOUNDATION_CONFIG_DIR/greeting.conf"
	run "${BASH:-bash}" "$cmd" Demo
	stub_called 'send-text --pane-id 700 --no-paste Show-TerminalGreeting --no-resize --settle --no-onefetch$'
	stub_called 'spawn .*FOUNDATION_SKIP_STARTUP_PANEL=1 '
	! stub_called 'FOUNDATION_STARTUP_NO_ONEFETCH' || false
}

@test "a comma list names several projects; an unknown flag opens nothing" {
	run "${BASH:-bash}" "$cmd" Demo,NoSuchProjectAnywhere
	[ "$status" -ne 0 ]
	stub_called 'set-tab-title --pane-id 700 Demo\.API'
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Demo --forse
	[ "$status" -eq 1 ]
	! stub_called 'spawn' || false
}

# A second project, and WezTerm with one window (4) holding pane 700, the pane every spawn returns.
two_projects() {
	mkdir -p "$BATS_TEST_TMPDIR/two/root"
	printf '\n[Two]\npath ROOT %s/two/root\ntab ROOT\n' "$BATS_TEST_TMPDIR" >>"$FOUNDATION_CONFIG_DIR/projects.conf"
	echo '[{"window_id":4,"tab_id":1,"pane_id":700,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///x"}]' >"$STUB_PANES"
}
new_windows() { grep -c 'spawn --new-window' "$STUB_LOG" || true; }

@test "new window + same group: all projects of the call share ONE new window" {
	two_projects
	run "${BASH:-bash}" "$cmd" Demo Two --new-window
	[ "$status" -eq 0 ]
	[ "$(new_windows)" -eq 1 ]
	[ "$(grep -c 'spawn --window-id 4 ' "$STUB_LOG")" -eq 2 ]
}

@test "new window + no same group: every tab in a window of its own; -InSameGroup:\$false works too" {
	two_projects
	run "${BASH:-bash}" "$cmd" Demo Two --new-window --no-in-same-group
	[ "$status" -eq 0 ]
	[ "$(new_windows)" -eq 3 ]
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Demo Two -InSameShell:\$false -InSameGroup:\$false --force
	[ "$(new_windows)" -eq 3 ]
}

@test "same shell + no same group: each project in a new window of its own" {
	two_projects
	run "${BASH:-bash}" "$cmd" Demo Two --in-same-shell --no-in-same-group
	[ "$status" -eq 0 ]
	[ "$(new_windows)" -eq 2 ]
}

@test "without a shell flag a window that already holds a project tab gets a new window, as on Windows" {
	two_projects
	echo '[{"window_id":3,"tab_id":9,"pane_id":5,"is_active":true,"tab_title":"Two.ROOT","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys005"}]' >"$STUB_PANES"
	export WEZTERM_PANE=5 STUB_TTY=ttys005
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called 'spawn --new-window'
	! stub_called 'spawn --window-id 3 ' || false
	# --alongside keeps the tabs in the alongside open's own window.
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Demo --alongside
	stub_called 'spawn --window-id 3 '
}

@test "without a shell flag and with two WezTerm windows the tabs open in a new window" {
	echo '[{"window_id":3,"tab_id":9,"pane_id":5,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys005"},{"window_id":8,"tab_id":10,"pane_id":6,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys006"}]' >"$STUB_PANES"
	export WEZTERM_PANE=5 STUB_TTY=ttys005
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called 'spawn --new-window'
	run "${BASH:-bash}" "$cmd" Demo --in-same-shell --force
	stub_called 'spawn --window-id 3 '
}

# WezTerm with one window (4): tab 1 holds pane 700 (the pane every spawn returns), tab 2 pane 701
# titled Demo.UI.
focus_window() {
	echo '[{"window_id":4,"tab_id":1,"pane_id":700,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///x"},{"window_id":4,"tab_id":2,"pane_id":701,"is_active":true,"tab_title":"Demo.UI","title":"zsh","cwd":"file:///x"}]' >"$STUB_PANES"
}

@test "--focus-tab: the first tab of the window by default, as on Windows; an index, a title or origin otherwise" {
	focus_window
	run "${BASH:-bash}" "$cmd" Demo --force
	[ "$status" -eq 0 ]
	[ "$(grep 'activate-pane' "$STUB_LOG" | tail -n 1)" = "wezterm cli --no-auto-start activate-pane --pane-id 700" ]
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Demo --force --focus-tab 1
	[ "$(grep 'activate-pane' "$STUB_LOG" | tail -n 1)" = "wezterm cli --no-auto-start activate-pane --pane-id 701" ]
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Demo --force -FocusTab demo.ui
	[ "$(grep 'activate-pane' "$STUB_LOG" | tail -n 1)" = "wezterm cli --no-auto-start activate-pane --pane-id 701" ]
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Demo --force --focus-tab Demo.Nothing
	[ "$status" -eq 0 ]
	! stub_called 'activate-pane' || false
	[[ $output == *"Tab [Demo.Nothing] not found"* ]]
}

@test "--focus-tab origin selects the tab this shell runs in" {
	echo '[{"window_id":4,"tab_id":1,"pane_id":5,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys005"},{"window_id":4,"tab_id":2,"pane_id":700,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///x"}]' >"$STUB_PANES"
	export WEZTERM_PANE=5 STUB_TTY=ttys005
	run "${BASH:-bash}" "$cmd" Demo --in-same-shell --focus-tab origin
	[ "$status" -eq 0 ]
	[ "$(grep 'activate-pane' "$STUB_LOG" | tail -n 1)" = "wezterm cli --no-auto-start activate-pane --pane-id 5" ]
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Demo --in-same-shell --focus-tab 1 --force
	[ "$(grep 'activate-pane' "$STUB_LOG" | tail -n 1)" = "wezterm cli --no-auto-start activate-pane --pane-id 700" ]
}

@test "tabs spread over several windows focus nothing; --focus-tab needs a value" {
	focus_window
	run "${BASH:-bash}" "$cmd" Demo --force --new-window --no-in-same-group
	[ "$status" -eq 0 ]
	! stub_called 'activate-pane' || false
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Demo --focus-tab
	[ "$status" -eq 1 ]
	! stub_called 'spawn' || false
}

@test "tab NAME ~ is a plain tab in the home folder titled <Project>.NAME (the Windows name-only tab)" {
	printf 'tab Scratch ~\n' >>"$FOUNDATION_CONFIG_DIR/projects.conf"
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called "spawn .*--cwd $HOME( |$)"
	stub_called 'set-tab-title --pane-id 700 Demo\.Scratch'
}
