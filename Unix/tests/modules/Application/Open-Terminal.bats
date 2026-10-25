#!/usr/bin/env bats
# Open-Terminal against the WezTerm stand-in: one tab per COMMAND (or --title / --cwd), the n-th
# title and directory going to the n-th tab, the first tab in a new window and the rest joining
# it, or the window of --window-id / of this WezTerm pane with --in-same-shell. A tab without
# --cwd starts on the Desktop, as on Windows.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	# The stand-in spawns every tab as pane 700; this list puts pane 700 in window 4, so the
	# tabs after the first join that window.
	echo '[{"window_id":4,"tab_id":1,"pane_id":700,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///x"}]' >"$STUB_PANES"
	one=$BATS_TEST_TMPDIR/one
	two=$BATS_TEST_TMPDIR/two
	mkdir -p "$one" "$two"
	cmd=$UNIX_DIR/modules/Application/bin/Open-Terminal
}

spawns() {
	grep -c ' spawn ' "$STUB_LOG" || true
}

# A home folder of the test's own with a Desktop, so no tab ever names the real one.
desktop_home() {
	export HOME=$BATS_TEST_TMPDIR/home
	mkdir -p "$HOME/Desktop"
}

@test "one titled tab per command in its directory, the first in a new window, the rest joining it" {
	run "${BASH:-bash}" "$cmd" 'npm run dev' lazygit --title Api --title Git --cwd "$one" --cwd "$two"
	[ "$status" -eq 0 ]
	[ "$(spawns)" -eq 2 ]
	stub_called "spawn --new-window --cwd $one$"
	stub_called "spawn --window-id 4 --cwd $two$"
	stub_called 'set-tab-title --pane-id 700 Api$'
	stub_called 'set-tab-title --pane-id 700 Git$'
	stub_called 'send-text --pane-id 700 --no-paste npm run dev$'
	stub_called 'send-text --pane-id 700 --no-paste lazygit$'
}

@test "titles alone open that many tabs on the Desktop, as on Windows, running nothing" {
	desktop_home
	cd "$one"
	run "${BASH:-bash}" "$cmd" --title A --title B
	[ "$status" -eq 0 ]
	[ "$(spawns)" -eq 2 ]
	[ "$(grep -c " spawn .*--cwd $HOME/Desktop$" "$STUB_LOG")" -eq 2 ]
	! stub_called 'send-text' || false
}

@test "the Windows spellings -Title, -Cwd and --command work, --administrator is ignored" {
	run "${BASH:-bash}" "$cmd" -Title Api -Cwd "$one" --command htop --administrator
	[ "$status" -eq 0 ]
	[ "$(spawns)" -eq 1 ]
	stub_called "spawn --new-window --cwd $one$"
	stub_called 'set-tab-title --pane-id 700 Api$'
	stub_called 'send-text --pane-id 700 --no-paste htop$'
}

@test "--window-id puts every tab in that window" {
	run "${BASH:-bash}" "$cmd" --title A --title B --window-id 42
	[ "$status" -eq 0 ]
	[ "$(grep -c ' spawn --window-id 42 ' "$STUB_LOG")" -eq 2 ]
	! stub_called 'spawn --new-window' || false
}

@test "--in-same-shell from a WezTerm pane joins its window and gives the pane focus back" {
	echo '[{"window_id":3,"tab_id":9,"pane_id":5,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys005"}]' >"$STUB_PANES"
	export WEZTERM_PANE=5 STUB_TTY=ttys005
	run "${BASH:-bash}" "$cmd" --title A --in-same-shell
	[ "$status" -eq 0 ]
	stub_called 'spawn --window-id 3 '
	stub_called 'activate-pane --pane-id 5$'
}

@test "--in-same-shell outside a WezTerm pane opens a new window and activates nothing" {
	run "${BASH:-bash}" "$cmd" --title A --in-same-shell
	[ "$status" -eq 0 ]
	stub_called 'spawn --new-window'
	! stub_called 'activate-pane' || false
}

@test "an untitled tab runs its command on the Desktop" {
	desktop_home
	cd "$one"
	run "${BASH:-bash}" "$cmd" 'npm run dev'
	[ "$status" -eq 0 ]
	stub_called "spawn --new-window --cwd $HOME/Desktop$"
	stub_called 'send-text --pane-id 700 --no-paste npm run dev$'
	! stub_called 'set-tab-title' || false
}

@test "a bare call opens one untitled tab on the Desktop, or home without one" {
	desktop_home
	cd "$one"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(spawns)" -eq 1 ]
	stub_called "spawn --new-window --cwd $HOME/Desktop$"
	rmdir "$HOME/Desktop"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd"
	stub_called "spawn --new-window --cwd $HOME$"
	! stub_called 'set-tab-title' || false
}

@test "the Windows arrays: -TabTitles A,B and -TabTitles \"A\", \"B\" name two tabs, -Command \"a\", \"b\" runs two" {
	run "${BASH:-bash}" "$cmd" -TabTitles Api,Git
	[ "$status" -eq 0 ]
	[ "$(spawns)" -eq 2 ]
	stub_called 'set-tab-title --pane-id 700 Api$'
	stub_called 'set-tab-title --pane-id 700 Git$'
	: >"$STUB_LOG"
	# PowerShell's "A", "B" reaches bash as `A,` `B`.
	run "${BASH:-bash}" "$cmd" -TabTitles Api, Git -Command 'npm run dev', lazygit
	[ "$status" -eq 0 ]
	[ "$(spawns)" -eq 2 ]
	stub_called 'set-tab-title --pane-id 700 Git$'
	stub_called 'send-text --pane-id 700 --no-paste npm run dev$'
	stub_called 'send-text --pane-id 700 --no-paste lazygit$'
	! stub_called 'set-tab-title --pane-id 700 Api,$' || false
}

@test "a comma inside one quoted command stays part of it" {
	run "${BASH:-bash}" "$cmd" --command 'echo a,b'
	[ "$status" -eq 0 ]
	[ "$(spawns)" -eq 1 ]
	stub_called 'send-text --pane-id 700 --no-paste echo a,b$'
}

@test "--window-id 0 is the window this shell runs in, as on Windows" {
	echo '[{"window_id":3,"tab_id":9,"pane_id":5,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys005"}]' >"$STUB_PANES"
	export WEZTERM_PANE=5 STUB_TTY=ttys005
	run "${BASH:-bash}" "$cmd" --title A --window-id 0
	[ "$status" -eq 0 ]
	stub_called 'spawn --window-id 3 '
	! stub_called 'spawn --window-id 0 ' || false
}

@test "a named --window-id opens a window once and later calls join it while it is open" {
	run "${BASH:-bash}" "$cmd" --title A --window-id Build
	[ "$status" -eq 0 ]
	stub_called 'spawn --new-window '
	[ "$(cat "$FOUNDATION_STATE_DIR/terminal-windows")" = $'Build\t4' ]
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" --title B --title C --window-id Build
	[ "$status" -eq 0 ]
	[ "$(grep -c ' spawn --window-id 4 ' "$STUB_LOG")" -eq 2 ]
	! stub_called 'spawn --new-window' || false
	# The window was closed: the name opens a new one and remembers that.
	echo '[{"window_id":9,"tab_id":1,"pane_id":700,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///x"}]' >"$STUB_PANES"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" --title D --window-id Build
	[ "$status" -eq 0 ]
	stub_called 'spawn --new-window '
	[ "$(cat "$FOUNDATION_STATE_DIR/terminal-windows")" = $'Build\t9' ]
}
