#!/usr/bin/env bats
# Terminate-WindowsTerminalTabs against the WezTerm and AeroSpace stand-ins (no real tab closes):
# every pane but this shell's by default, this one last with --include-current, only this one
# (refocusing the desktop afterwards) with --only-current; an inherited WEZTERM_PANE is no own pane.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	# Pane 5 is this shell (its tty is ours once STUB_TTY says so); 6 and 7 are other tabs.
	cat >"$STUB_PANES" <<'JSON'
[{"window_id":1,"tab_id":2,"pane_id":5,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys005"},
 {"window_id":1,"tab_id":3,"pane_id":6,"is_active":false,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys006"},
 {"window_id":2,"tab_id":4,"pane_id":7,"is_active":false,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys007"}]
JSON
	cp "$STUB_PANES" "$BATS_TEST_TMPDIR/panes.orig"
	export WEZTERM_PANE=5 STUB_TTY=ttys005
	cmd=$UNIX_DIR/modules/System/bin/Terminate-WindowsTerminalTabs
}

# The panes killed, in order, space-separated.
killed() {
	sed -n 's/.*kill-pane --pane-id \([0-9]*\)$/\1/p' "$STUB_LOG" | tr '\n' ' ' | sed 's/ $//'
}

@test "every pane except this shell's is closed" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(killed)" = "6 7" ]
}

@test "--include-current (and the Windows -IncludeCurrent) closes this pane too, last" {
	run "${BASH:-bash}" "$cmd" --include-current
	[ "$status" -eq 0 ]
	[ "$(killed)" = "6 7 5" ]
	# The stand-in removed the killed panes: put them back for the second run.
	cp "$BATS_TEST_TMPDIR/panes.orig" "$STUB_PANES"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" -IncludeCurrent
	[ "$(killed)" = "6 7 5" ]
}

@test "--only-current closes only this pane and refocuses the desktop that was focused" {
	echo 3 >"$BATS_TEST_TMPDIR/focused"
	run "${BASH:-bash}" "$cmd" --only-current
	[ "$status" -eq 0 ]
	[ "$(killed)" = "5" ]
	stub_wait_for '^aerospace workspace -- 3$'
}

@test "--only-current outside WezTerm closes nothing" {
	unset STUB_TTY
	run "${BASH:-bash}" "$cmd" --only-current
	[ "$status" -eq 0 ]
	[ -z "$(killed)" ]
}

@test "an inherited WEZTERM_PANE outside its pane is not spared" {
	unset STUB_TTY
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(killed)" = "5 6 7" ]
}

@test "WezTerm not running closes nothing" {
	cat >"$STUB_BIN/wezterm" <<'SH'
#!/bin/sh
echo "wezterm $*" >>"$STUB_LOG"
exit 1
SH
	run "${BASH:-bash}" "$cmd" --include-current
	[ "$status" -eq 0 ]
	[ -z "$(killed)" ]
}

@test "a split pane of this shell's tab stays; --include-current closes it before this pane" {
	command -v jq >/dev/null 2>&1 || skip "jq is required by the WezTerm driver"
	# Pane 8 is split next to this shell's pane 5, in tab 2.
	jq '. + [{"window_id":1,"tab_id":2,"pane_id":8,"is_active":false,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys008"}]' "$STUB_PANES" >"$STUB_PANES.new" && mv "$STUB_PANES.new" "$STUB_PANES"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(killed)" = "6 7" ]
	[[ $output == *"Closed 2 terminal tab(s)!"* ]]
	: >"$STUB_LOG"
	jq '. + [{"window_id":1,"tab_id":3,"pane_id":6,"is_active":false,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys006"}]' "$STUB_PANES" >"$STUB_PANES.new" && mv "$STUB_PANES.new" "$STUB_PANES"
	run "${BASH:-bash}" "$cmd" --include-current
	[ "$(killed)" = "6 8 5" ]
}

@test "a tab that does not close is reported in a warning" {
	command -v jq >/dev/null 2>&1 || skip "jq is required by the WezTerm driver"
	echo 7 >"$BATS_TEST_TMPDIR/stuck-panes"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(killed)" = "6 7" ]
	[[ $output == *"Closed 1 terminal tab(s), but the cleanup left 1 tab(s) open"* ]]
}

@test "--close-wait-seconds (the Windows -CloseWaitSeconds) counts down before this tab closes" {
	run "${BASH:-bash}" "$cmd" -OnlyCurrent -CloseWaitSeconds 1
	[ "$status" -eq 0 ]
	[[ $output == *"Closing this terminal tab in:"* ]]
	[ "$(killed)" = "5" ]
	: >"$STUB_LOG"
	# Without a current tab to close, nothing counts down.
	run "${BASH:-bash}" "$cmd" --close-wait-seconds 1
	[[ $output != *"Closing this terminal tab in:"* ]]
}

@test "--close-wait-seconds outside 0-300 closes nothing" {
	run "${BASH:-bash}" "$cmd" --include-current --close-wait-seconds 301
	[ "$status" -eq 1 ]
	[ -z "$(killed)" ]
	run "${BASH:-bash}" "$cmd" --close-wait-seconds soon
	[ "$status" -eq 1 ]
	[ -z "$(killed)" ]
}
