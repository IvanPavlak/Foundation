#!/usr/bin/env bats
# Kill-All against the platform stand-ins: browsers and every windowed app are quit Cmd+Q style,
# the keep apps (terminal, Finder) survive, --exclude keeps an app, --skip turns a step off, and
# the windows still open afterwards are reported. The stand-ins never close a window, so every
# quit app's window is still listed when the survivor audit runs.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	stub_window 100 com.github.wez.wezterm 2 WezTerm "[1/1] zsh"
	stub_window 110 com.apple.finder 2 Finder "Downloads"
	stub_window 200 com.microsoft.VSCode 1 Code "Dotfiles"
	stub_window 300 org.mozilla.firefox 3 Firefox "YouTube"
	cmd=$UNIX_DIR/modules/System/bin/Kill-All
}

@test "browsers and windowed apps quit, the terminal and Finder stay, desktop 1 is focused" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called 'quit app id "org\.mozilla\.firefox"'
	stub_called 'quit app id "com\.microsoft\.VSCode"'
	! stub_called 'quit app id "com\.github\.wez\.wezterm"' || false
	! stub_called 'quit app id "com\.apple\.finder"' || false
	stub_called '^aerospace workspace -- 1'
}

@test "--exclude keeps an app, positional and comma lists work like Windows" {
	run "${BASH:-bash}" "$cmd" --exclude Code
	! stub_called 'quit app id "com\.microsoft\.VSCode"' || false
	stub_called 'quit app id "org\.mozilla\.firefox"'
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Code,Firefox
	! stub_called 'quit app id "com\.microsoft\.VSCode"' || false
	! stub_called 'quit app id "org\.mozilla\.firefox"' || false
}

@test "--skip turns a step off for one run" {
	run "${BASH:-bash}" "$cmd" --skip Browsers
	! stub_called 'quit app id "org\.mozilla\.firefox"' || false
	stub_called 'quit app id "com\.microsoft\.VSCode"'
}

@test "windows still open after the cleanup are reported, keep apps, Finder and excludes are not" {
	run "${BASH:-bash}" "$cmd" --exclude Code
	[ "$status" -eq 0 ]
	[[ $output == *"1 window(s) survived the cleanup"* ]]
	[[ $output == *"  - YouTube (Firefox, PID 99999999)"* ]]
	[[ $output != *"Dotfiles (Code"* ]]
	[[ $output != *"zsh (WezTerm"* ]]
	[[ $output != *"Downloads (Finder"* ]]
	[[ $output != *"finished successfully"* ]]
}

@test "only keep apps left is a clean run; a skipped cleanup step skips the audit" {
	grep -v '^[23]00|' "$STUB_WINDOWS" >"$STUB_WINDOWS.tmp" && mv "$STUB_WINDOWS.tmp" "$STUB_WINDOWS"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Kill All finished successfully!"* ]]
	[[ $output != *survived* ]]
	stub_window 300 org.mozilla.firefox 3 Firefox "YouTube"
	run "${BASH:-bash}" "$cmd" --skip NamedProcesses
	[ "$status" -eq 0 ]
	[[ $output != *survived* ]]
}

@test "a step with no line anywhere behaves like the base kill-all.conf line" {
	copy_fixture_config
	# Take the base Browsers and MoveTerminal lines back: Browsers still runs (base on) and
	# MoveTerminal still does not (base off).
	printf '%s\n' '-step Browsers on' '-step MoveTerminal off' >"$FOUNDATION_CONFIG_DIR/kill-all.local.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called 'quit app id "org\.mozilla\.firefox"'
	! stub_called '^aerospace move-node-to-workspace' || false
	: >"$STUB_LOG"
	# Firefox quit in the first run; it runs again for the second.
	echo org.mozilla.firefox >>"$STUB_RUNNING"
	# Without any kill-all.conf every step but MoveTerminal, CenterTerminal and ReloadProfile runs.
	rm "$FOUNDATION_CONFIG_DIR/kill-all.conf" "$FOUNDATION_CONFIG_DIR/kill-all.local.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called 'quit app id "org\.mozilla\.firefox"'
	stub_called '^aerospace workspace -- 1'
	[[ $output != *"Reload-Profile"* ]]
}

@test "a step name that is no Kill-All step stops it before anything is closed" {
	run "${BASH:-bash}" "$cmd" --skip Browsrs
	[ "$status" -eq 1 ]
	[[ $output == *"Unknown step [Browsrs]"* ]]
	[ ! -s "$STUB_LOG" ]
	# Step names compare case-insensitively, as on Windows.
	run "${BASH:-bash}" "$cmd" --skip browsers
	[ "$status" -eq 0 ]
	! stub_called 'quit app id "org\.mozilla\.firefox"' || false
}

@test "a browser that ignores the quit is asked twice, named in a warning and never killed" {
	echo org.mozilla.firefox >"$BATS_TEST_TMPDIR/ignores-quit"
	FOUNDATION_BROWSER_QUIT_SECONDS=0 FOUNDATION_BROWSER_RETRY_SECONDS=0 run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(grep -c 'quit app id "org\.mozilla\.firefox"' "$STUB_LOG")" -eq 2 ]
	[[ $output == *"1 browser(s) did not quit"* ]]
	[[ $output == *"  - YouTube (Firefox)"* ]]
	[[ $output != *"Browsers processed"* ]]
	# Still running: nothing removed it, as a kill would have to.
	grep -qxF org.mozilla.firefox "$STUB_RUNNING"
}

@test "a browser that quits on the first request is asked once and the step succeeds" {
	run "${BASH:-bash}" "$cmd"
	[ "$(grep -c 'quit app id "org\.mozilla\.firefox"' "$STUB_LOG")" -eq 1 ]
	[[ $output == *"Browsers processed (1 quit, 0 window(s) closed)!"* ]]
	[[ $output != *"did not quit"* ]]
}

@test "a quit name that is no app ends that process: pkill, then pkill -9 when it stays" {
	copy_fixture_config
	printf 'quit VBoxSVC\nquit stubborn-helper\n' >"$FOUNDATION_CONFIG_DIR/kill-all.local.conf"
	printf 'VBoxSVC\nstubborn-helper\n' >"$BATS_TEST_TMPDIR/processes"
	echo stubborn-helper >"$BATS_TEST_TMPDIR/ignores-term"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^pkill -x -- VBoxSVC$'
	! stub_called '^pkill -9 -x -- VBoxSVC$' || false
	stub_called '^pkill -9 -x -- stubborn-helper$'
	[ ! -s "$BATS_TEST_TMPDIR/processes" ]
	[[ $output == *"Named applications processed (3)!"* ]]
}

@test "without any quit line the NamedProcesses step warns, as on Windows" {
	copy_fixture_config
	printf -- '-quit Code\n' >"$FOUNDATION_CONFIG_DIR/kill-all.local.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"No quit lines in kill-all.conf"* ]]
	! stub_called '^pkill' || false
}

@test "a full run clears every Close-Workspace record; a skipped sweep step keeps them" {
	record=$FOUNDATION_STATE_DIR/open-workspaces
	printf 'Demo\twindow\t200\tCode\tcom.microsoft.VSCode\tDotfiles\nDemo#2\tmeta\talongside\nOther\tpane\t7\tT\n' >"$record"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -s "$record" ]
	printf 'Demo\twindow\t200\tCode\tcom.microsoft.VSCode\tDotfiles\n' >"$record"
	run "${BASH:-bash}" "$cmd" --skip VisibleWindows
	[ "$status" -eq 0 ]
	grep -q '^Demo' "$record"
}

@test "an excluded window keeps its app: the app's other windows close one by one" {
	stub_window 201 com.microsoft.VSCode 1 Code "Notes"
	run "${BASH:-bash}" "$cmd" --exclude '*Dotfiles*'
	[ "$status" -eq 0 ]
	stub_called '^aerospace close --window-id 201'
	! stub_called '^aerospace close --window-id 200' || false
	# Neither VisibleWindows nor the `quit Code` line quits it.
	! stub_called 'quit app id "com\.microsoft\.VSCode"' || false
	[[ $output == *"Applications processed (0 quit, 1 window(s) closed)!"* ]]
}

@test "the terminal is never quit, even without a keep Terminal line" {
	copy_fixture_config
	printf -- '-keep Terminal\n' >"$FOUNDATION_CONFIG_DIR/kill-all.local.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	! stub_called 'quit app id "com\.github\.wez\.wezterm"' || false
	stub_called 'quit app id "com\.microsoft\.VSCode"'
	[[ $output != *"zsh (WezTerm"* ]]
}

@test "without any keep line VisibleWindows warns and quits nothing, as on Windows" {
	copy_fixture_config
	printf -- '-keep Terminal\n-keep Finder\n-keep Docker\n' >"$FOUNDATION_CONFIG_DIR/kill-all.local.conf"
	run "${BASH:-bash}" "$cmd" --skip NamedProcesses
	[ "$status" -eq 0 ]
	[[ $output == *"No keep lines in kill-all.conf - no application with a visible window was quit"* ]]
	! stub_called 'quit app id "com\.microsoft\.VSCode"' || false
	! stub_called 'quit app id "com\.apple\.finder"' || false
	# The browsers are their own step and still go.
	stub_called 'quit app id "org\.mozilla\.firefox"'
}

@test "TerminalTabs closes the other tabs, FocusTerminal focuses the terminal window" {
	command -v jq >/dev/null 2>&1 || skip "jq is required by the WezTerm driver"
	echo '[{"window_id":1,"tab_id":2,"pane_id":5,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys005"},{"window_id":1,"tab_id":3,"pane_id":6,"is_active":false,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys006"}]' >"$STUB_PANES"
	export WEZTERM_PANE=5 STUB_TTY=ttys005
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called 'kill-pane --pane-id 6$'
	! stub_called 'kill-pane --pane-id 5$' || false
	stub_called '^aerospace focus --window-id 100$'
}

@test "--include-current (the Windows -IncludeCurrent) closes this tab last and skips the terminal focus" {
	command -v jq >/dev/null 2>&1 || skip "jq is required by the WezTerm driver"
	echo '[{"window_id":1,"tab_id":2,"pane_id":5,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys005"},{"window_id":1,"tab_id":3,"pane_id":6,"is_active":false,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys006"}]' >"$STUB_PANES"
	export WEZTERM_PANE=5 STUB_TTY=ttys005
	run "${BASH:-bash}" "$cmd" -IncludeCurrent
	[ "$status" -eq 0 ]
	[ "$(sed -n 's/.*kill-pane --pane-id \([0-9]*\)$/\1/p' "$STUB_LOG" | tr '\n' ' ')" = "6 5 " ]
	! stub_called '^aerospace focus --window-id' || false
}

@test "step TerminalTabs off closes no tab; --reload-profile prints the Reload-Profile hint" {
	command -v jq >/dev/null 2>&1 || skip "jq is required by the WezTerm driver"
	echo '[{"window_id":1,"tab_id":3,"pane_id":6,"is_active":false,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys006"}]' >"$STUB_PANES"
	copy_fixture_config
	printf 'step TerminalTabs off\n' >"$FOUNDATION_CONFIG_DIR/kill-all.local.conf"
	run "${BASH:-bash}" "$cmd" -ReloadPowerShellProfile
	[ "$status" -eq 0 ]
	! stub_called 'kill-pane' || false
	[[ $output == *"Reload the shell configuration with => Reload-Profile"* ]]
}
