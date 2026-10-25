#!/usr/bin/env bats
# Close-ProjectTerminals against the WezTerm stand-in: every pane of a <Project>.* tab is killed
# (case-insensitive) except the whole tab this shell runs in, and a WEZTERM_PANE whose tty is not
# this process's terminal (inherited by an app started from WezTerm) spares nothing.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	stub_config
	# Tab 2 holds this shell (pane 5) and a split (pane 6); tab 3 is another Demo tab; tab 4 is
	# another project's.
	cat >"$STUB_PANES" <<'JSON'
[{"window_id":1,"tab_id":2,"pane_id":5,"is_active":true,"tab_title":"Demo.API","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys005"},
 {"window_id":1,"tab_id":2,"pane_id":6,"is_active":false,"tab_title":"Demo.API","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys006"},
 {"window_id":1,"tab_id":3,"pane_id":7,"is_active":false,"tab_title":"demo.ui","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys007"},
 {"window_id":1,"tab_id":4,"pane_id":8,"is_active":false,"tab_title":"Other.X","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys008"}]
JSON
	export WEZTERM_PANE=5
	cmd=$UNIX_DIR/modules/Workflow/bin/Close-ProjectTerminals
}

@test "the project's other tabs close; the calling tab stays whole, split panes included" {
	export STUB_TTY=ttys005
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called 'kill-pane --pane-id 7$'
	! stub_called 'kill-pane --pane-id 5$' || false
	! stub_called 'kill-pane --pane-id 6$' || false
	! stub_called 'kill-pane --pane-id 8$' || false
}

@test "an inherited WEZTERM_PANE outside its pane spares nothing" {
	unset STUB_TTY
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called 'kill-pane --pane-id 5$'
	stub_called 'kill-pane --pane-id 6$'
	stub_called 'kill-pane --pane-id 7$'
	! stub_called 'kill-pane --pane-id 8$' || false
}

@test "without a project it fails and kills nothing" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	! stub_called 'kill-pane' || false
}

@test "a comma list names several projects, as -ProjectName Demo,Other does" {
	export STUB_TTY=ttys005
	run "${BASH:-bash}" "$cmd" -ProjectName Demo,Other
	[ "$status" -eq 0 ]
	stub_called 'kill-pane --pane-id 7$'
	stub_called 'kill-pane --pane-id 8$'
	! stub_called 'kill-pane --pane-id 5$' || false
}
