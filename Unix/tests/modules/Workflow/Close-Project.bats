#!/usr/bin/env bats
# Close-Project against the stand-ins: the project's browser windows close (in Safari only its
# tabs, whole windows again without Automation), other windows stay, and focus returns to the
# window the command was typed in (or this shell's terminal window when that one was closed); a
# menu number names the project.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	stub_config
	printf '\n[Demo]\npath ROOT %s\ntab ROOT\n' "$BATS_TEST_TMPDIR" >>"$FOUNDATION_CONFIG_DIR/projects.conf"
	stub_window 100 com.github.wez.wezterm 1 WezTerm 'zsh'
	stub_window 300 org.mozilla.firefox 1 Firefox 'Demo - Mozilla Firefox'
	stub_window 301 org.mozilla.firefox 1 Firefox 'Other - Mozilla Firefox'
	cmd=$UNIX_DIR/modules/Workflow/bin/Close-Project
}

@test "the project's browser window closes and focus returns to the calling window" {
	echo 100 >"$BATS_TEST_TMPDIR/focused-window"
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called 'close --window-id 300$'
	! stub_called 'close --window-id 301$' || false
	[ "$(grep '^aerospace focus' "$STUB_LOG" | tail -1)" = "aerospace focus --window-id 100" ]
}

@test "when the calling window was closed, the terminal window gets focus" {
	echo 300 >"$BATS_TEST_TMPDIR/focused-window"
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called 'close --window-id 300$'
	[ "$(grep '^aerospace focus' "$STUB_LOG" | tail -1)" = "aerospace focus --window-id 100" ]
}

@test "a number names that entry of the menu, as -Project 2 does on Windows" {
	foundation_load config project
	n=$(project_names | grep -nx Demo | cut -d: -f1)
	echo 100 >"$BATS_TEST_TMPDIR/focused-window"
	run "${BASH:-bash}" "$cmd" "$n"
	[ "$status" -eq 0 ]
	stub_called 'close --window-id 300$'
	! stub_called 'close --window-id 301$' || false
}

@test "an unknown project fails and closes nothing" {
	run "${BASH:-bash}" "$cmd" NoSuchProjectAnywhere
	[ "$status" -ne 0 ]
	! stub_called 'close --window-id' || false
}

@test "Safari: only the tabs whose title or URL names the project close, the window stays" {
	stub_window 400 com.apple.Safari 1 Safari 'Demo docs'
	printf 'com.apple.Safari\t1\thttps://docs.example/\tDemo docs\ncom.apple.Safari\t1\thttps://code.example/me/demo\tCode\ncom.apple.Safari\t1\thttps://other.example/\tOther\n' >"$STUB_TABS"
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	[ "$(cut -f4 "$STUB_TABS")" = Other ]
	! stub_called 'close --window-id 400$' || false
	[[ $output == *"2 browser tab(s)"* ]]
	# Firefox cannot be scripted: its matching window still closes whole.
	stub_called 'close --window-id 300$'
}

@test "Safari without Automation: its matching window closes as a whole" {
	stub_window 400 com.apple.Safari 1 Safari 'Demo docs'
	touch "$BATS_TEST_TMPDIR/automation-refused"
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called 'close --window-id 400$'
	[[ $output == *"Privacy & Security > Automation"* ]]
}

@test "a comma list names several projects; an unknown flag closes nothing" {
	echo 100 >"$BATS_TEST_TMPDIR/focused-window"
	run "${BASH:-bash}" "$cmd" -Project Demo,NoSuchProjectAnywhere
	[ "$status" -ne 0 ]
	stub_called 'close --window-id 300$'
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Demo --bogus
	[ "$status" -eq 1 ]
	! stub_called 'close --window-id' || false
}

@test "VS Code: the project's folder window closes, a similarly named one stays" {
	printf 'action Open-VSCode Demo\n' >>"$FOUNDATION_CONFIG_DIR/projects.conf"
	printf 'Demo  %s/Demo\n' "$BATS_TEST_TMPDIR" >>"$FOUNDATION_CONFIG_DIR/vscode-folders.conf"
	stub_window 200 com.microsoft.VSCode 1 Code 'Demo - Visual Studio Code'
	stub_window 201 com.microsoft.VSCode 1 Code 'demo-ui - Visual Studio Code'
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called 'close --window-id 200$'
	! stub_called 'close --window-id 201$' || false
}

@test "Swagger UI closes only for a project with a [Swagger] entry" {
	stub_window 302 org.mozilla.firefox 1 Firefox 'Swagger UI - Mozilla Firefox'
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	! stub_called 'close --window-id 302$' || false
	printf '\n[Swagger]\nDemo http://localhost:5000/swagger\n' >>"$FOUNDATION_CONFIG_DIR/browser-groups.conf"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called 'close --window-id 302$'
}

@test "Problem loading page closes only for a Swagger entry on this machine, as on Windows" {
	stub_window 302 org.mozilla.firefox 1 Firefox 'Problem loading page - Mozilla Firefox'
	printf '\n[Swagger]\nDemo https://api.example.com/swagger\n' >>"$FOUNDATION_CONFIG_DIR/browser-groups.conf"
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	! stub_called 'close --window-id 302$' || false
	sed -i.bak 's|https://api\.example\.com/swagger|http://127.0.0.1:5000/swagger|' "$FOUNDATION_CONFIG_DIR/browser-groups.conf"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called 'close --window-id 302$'
}
