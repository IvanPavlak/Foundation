#!/usr/bin/env bats
# Focus-TerminalTab against the stand-ins: the window focused is the one whose WezTerm title
# ("[i/n] TITLE") belongs to this shell's pane, the focused window breaks a tie, and outside a
# WezTerm pane the first terminal window is used.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	stub_config
	cmd=$UNIX_DIR/modules/Workflow/bin/Focus-TerminalTab
}

# Two WezTerm windows of two tabs each; this shell is pane 3, the second tab of window 1.
two_windows() {
	cat >"$STUB_PANES" <<'JSON'
[{"window_id":0,"tab_id":0,"pane_id":0,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys000"},
 {"window_id":0,"tab_id":1,"pane_id":1,"is_active":false,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys001"},
 {"window_id":1,"tab_id":2,"pane_id":2,"is_active":false,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys002"},
 {"window_id":1,"tab_id":3,"pane_id":3,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys003"}]
JSON
	stub_window 100 com.github.wez.wezterm 1 WezTerm '[1/2] zsh'
	stub_window 101 com.github.wez.wezterm 2 WezTerm '[2/2] zsh'
	export WEZTERM_PANE=3
}

@test "the window titled after this shell's tab is focused, not the first terminal" {
	two_windows
	export STUB_TTY=ttys003
	run "${BASH:-bash}" "$cmd" --quiet
	[ "$status" -eq 0 ]
	stub_called 'activate-pane --pane-id 3$'
	[ "$(grep '^aerospace focus' "$STUB_LOG" | tail -1)" = "aerospace focus --window-id 101" ]
}

@test "two windows with the same title: the focused one wins" {
	cat >"$STUB_PANES" <<'JSON'
[{"window_id":0,"tab_id":0,"pane_id":0,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys000"},
 {"window_id":1,"tab_id":1,"pane_id":1,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys001"}]
JSON
	stub_window 100 com.github.wez.wezterm 1 WezTerm 'zsh'
	stub_window 101 com.github.wez.wezterm 1 WezTerm 'zsh'
	echo 101 >"$BATS_TEST_TMPDIR/focused-window"
	export WEZTERM_PANE=1 STUB_TTY=ttys001
	run "${BASH:-bash}" "$cmd" --quiet
	[ "$status" -eq 0 ]
	[ "$(grep '^aerospace focus' "$STUB_LOG" | tail -1)" = "aerospace focus --window-id 101" ]
}

@test "an inherited WEZTERM_PANE outside its pane activates nothing and takes the first terminal" {
	two_windows
	unset STUB_TTY
	run "${BASH:-bash}" "$cmd" --quiet
	[ "$status" -eq 0 ]
	! stub_called 'activate-pane' || false
	[ "$(grep '^aerospace focus' "$STUB_LOG" | tail -1)" = "aerospace focus --window-id 100" ]
}

@test "no terminal window fails" {
	stub_window 300 org.mozilla.firefox 1 Firefox 'Page - Mozilla Firefox'
	run "${BASH:-bash}" "$cmd" --quiet
	[ "$status" -ne 0 ]
	! stub_called 'aerospace focus' || false
}

@test "the Windows -Quiet in any case is --quiet; an unknown flag focuses nothing" {
	two_windows
	export STUB_TTY=ttys003
	run "${BASH:-bash}" "$cmd" -quiet
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	stub_called '^aerospace focus'
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" --quite
	[ "$status" -eq 1 ]
	! stub_called '^aerospace focus' || false
}

@test "--target-title focuses the tab of that title in whichever window holds it" {
	cat >"$STUB_PANES" <<'JSON'
[{"window_id":0,"tab_id":0,"pane_id":0,"is_active":true,"tab_title":"Demo.API","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys000"},
 {"window_id":1,"tab_id":1,"pane_id":1,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys001"},
 {"window_id":1,"tab_id":2,"pane_id":2,"is_active":false,"tab_title":"Demo.UI","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys002"}]
JSON
	stub_window 100 com.github.wez.wezterm 1 WezTerm 'Demo.API'
	stub_window 101 com.github.wez.wezterm 2 WezTerm '[1/2] zsh'
	export WEZTERM_PANE=1 STUB_TTY=ttys001
	run "${BASH:-bash}" "$cmd" -TargetTitle demo.ui --quiet
	[ "$status" -eq 0 ]
	stub_called 'activate-pane --pane-id 2$'
	! stub_called 'activate-pane --pane-id 1$' || false
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" --target-title NoSuchTab
	[ "$status" -eq 1 ]
	! stub_called 'activate-pane' || false
	! stub_called '^aerospace focus' || false
}
