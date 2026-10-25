#!/usr/bin/env bats
# Get-WorkspaceState against an ownership record in the test state folder and the platform
# stand-ins: every recorded workspace or only the named ones, each window and tab marked live or
# gone by what AeroSpace and WezTerm report, and --raw printing the record lines unchanged.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	record=$FOUNDATION_STATE_DIR/open-workspaces
	printf '%s\n' \
		$'Alpha\twindow\t100\tCode\tcom.microsoft.VSCode\tmain.ts - SampleApi' \
		$'Alpha\twindow\t200\tFirefox\torg.mozilla.firefox\tSample Docs' \
		$'Alpha\tpane\t42\tSampleApi.API' \
		$'Beta\twindow\t300\tSlack\tcom.tinyspeck.slackmacgap\tSlack' >"$record"
	stub_window 100 com.microsoft.VSCode 1 Code "main.ts - SampleApi"
	stub_window 300 com.tinyspeck.slackmacgap 2 Slack "Slack"
	cmd=$UNIX_DIR/modules/Workflow/bin/Get-WorkspaceState
}

# The output line of window or pane ID.
line_of() { # ID
	printf '%s\n' "$output" | grep -E "\($1\)"
}

@test "every recorded workspace is shown, each window marked live or gone" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"[Alpha]"*"[Beta]"* ]]
	[[ $(line_of 100) == *live*"window"*"Code"*"main.ts - SampleApi"* ]]
	[[ $(line_of 200) == *gone*"window"*"Firefox"*"Sample Docs"* ]]
	[[ $(line_of 300) == *live*"Slack"* ]]
}

@test "named workspaces only, matched case-insensitively" {
	run "${BASH:-bash}" "$cmd" beta
	[ "$status" -eq 0 ]
	[[ $output == *"(300)"* ]]
	[[ $output != *"(100)"* ]]
	[[ $output != *"[Alpha]"* ]]
}

@test "a terminal tab is live while WezTerm reports its pane, gone otherwise" {
	command -v jq >/dev/null 2>&1 || skip "jq is required by the WezTerm driver"
	run "${BASH:-bash}" "$cmd" Alpha
	[[ $(line_of 42) == *gone*"tab"*"SampleApi.API"* ]]
	echo '[{"window_id":1,"tab_id":7,"pane_id":42,"is_active":true,"tab_title":"SampleApi.API","title":"zsh","cwd":"file:///tmp","tty_name":"/dev/ttys001"}]' >"$STUB_PANES"
	run "${BASH:-bash}" "$cmd" Alpha
	[ "$status" -eq 0 ]
	[[ $(line_of 42) == *live*"tab"*"SampleApi.API"* ]]
}

@test "without AeroSpace every window is gone" {
	printf '#!/bin/sh\necho "aerospace $*" >>"$STUB_LOG"\nexit 1\n' >"$STUB_BIN/aerospace"
	run "${BASH:-bash}" "$cmd" Alpha
	[ "$status" -eq 0 ]
	[[ $(line_of 100) == *gone* ]]
}

@test "--raw prints the record lines of the workspace unchanged" {
	run "${BASH:-bash}" "$cmd" Beta --raw
	[ "$status" -eq 0 ]
	[ "$output" = $'Beta\twindow\t300\tSlack\tcom.tinyspeck.slackmacgap\tSlack' ]
	run "${BASH:-bash}" "$cmd" --raw
	[ "$output" = "$(cat "$record")" ]
}

@test "a named workspace without entries shows nothing recorded" {
	run "${BASH:-bash}" "$cmd" NoSuchWorkspace
	[ "$status" -eq 0 ]
	[[ $output == *"[NoSuchWorkspace]"*"(nothing recorded)"* ]]
	run "${BASH:-bash}" "$cmd" NoSuchWorkspace --raw
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "no record at all: nothing is open and nothing is asked of the platform" {
	rm "$record"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output != *"window"* ]]
	! stub_called '^aerospace list-windows' || false
}

@test "a comma list names several workspaces; an unknown flag is an error" {
	run "${BASH:-bash}" "$cmd" alpha,beta
	[ "$status" -eq 0 ]
	[[ $output == *"(100)"* ]]
	[[ $output == *"(300)"* ]]
	run "${BASH:-bash}" "$cmd" --rwa
	[ "$status" -eq 1 ]
}

@test "a workspace open twice shows each instance under its label; --raw keeps the instance key" {
	printf '%s\n' $'Beta#2\twindow\t400\tFirefox\torg.mozilla.firefox\tSide' $'Beta#2\tmeta\talongside' >>"$record"
	stub_window 400 org.mozilla.firefox 6 Firefox "Side"
	run "${BASH:-bash}" "$cmd" Beta
	[ "$status" -eq 0 ]
	[[ $output == *"Beta (plain, desktop 2)"*"(300)"*"Beta (alongside, desktop 6)"*"(400)"* ]]
	run "${BASH:-bash}" "$cmd" Beta --raw
	[[ $output == *$'Beta#2\twindow\t400\tFirefox'* ]]
}

@test "a window the app recreated is live under its new id, as cw finds it" {
	# Alpha's Firefox window 200 is gone; Firefox's one live window now is 210.
	stub_window 210 org.mozilla.firefox 1 Firefox "Sample Docs"
	run "${BASH:-bash}" "$cmd" Alpha
	[ "$status" -eq 0 ]
	[[ $(line_of '200, now 210') == *live*"Firefox"* ]]
}
