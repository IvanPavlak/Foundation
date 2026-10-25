#!/usr/bin/env bats
# lib/terminal.sh, the deferred terminal commands: during a run term_defer queues, and
# term_flush_deferred sends each to its pane when the pane is still there, skips a gone one and
# empties the queue; without a run directory term_defer sends at once. WezTerm is the stand-in of
# tests/platform.bash.

load helpers
load platform

setup() {
	setup_foundation
	platform_stubs
	foundation_load config apps drivers/wezterm terminal
	# One live pane, 5.
	echo '[{"window_id":1,"tab_id":1,"pane_id":5,"is_active":true,"tab_title":"","title":"zsh","cwd":"file:///tmp","tty_name":"/dev/ttys001"}]' >"$STUB_PANES"
}

@test "term_flush_deferred sends to the live pane only, skips the gone one and empties the queue" {
	export FOUNDATION_RUN_DIR=$BATS_TEST_TMPDIR/run
	mkdir -p "$FOUNDATION_RUN_DIR"
	term_defer 5 'echo live'
	term_defer 9 'echo gone'
	[ "$(wc -l <"$FOUNDATION_RUN_DIR/deferred" | tr -d ' ')" -eq 2 ]
	! stub_called 'send-text' || false
	term_flush_deferred
	stub_called 'send-text --pane-id 5 --no-paste echo live'
	! stub_called 'pane-id 9' || false
	[ -f "$FOUNDATION_RUN_DIR/deferred" ]
	[ ! -s "$FOUNDATION_RUN_DIR/deferred" ]
	# An empty queue sends nothing more.
	: >"$STUB_LOG"
	term_flush_deferred
	! stub_called 'send-text' || false
}

@test "term_defer without a run directory sends at once" {
	unset FOUNDATION_RUN_DIR
	term_defer 5 'echo now'
	stub_called 'send-text --pane-id 5 --no-paste echo now'
}
