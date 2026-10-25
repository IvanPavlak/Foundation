#!/usr/bin/env bats
# Open-Browser against the platform and browser stand-ins: a group (or its index path in the menu
# tree) opens its URLs in one new window, a rerun skips the group whose window still exists,
# --force reopens it, --no-menu --instances fills up to N windows, and a search goes to Google. Safari opens a group through the
# browser scripting driver and knows it is open from its tabs' URLs; without Automation it fails.
# --alongside opens next to what is open, and a cold start waits for the first window. The
# windows a workspace open protects are neither counted nor taken for an open group.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	stub_config
	printf '\n[TestGroup]\nOne https://one.example/\nTwo https://two.example/\n' >>"$FOUNDATION_CONFIG_DIR/browser-groups.conf"
	cmd=$UNIX_DIR/modules/Application/bin/Open-Browser
}

@test "a group opens all its URLs in one launch, and a rerun skips it" {
	run "${BASH:-bash}" "$cmd" TestGroup
	[ "$status" -eq 0 ]
	stub_called '^launch Firefox https://one\.example/ https://two\.example/'
	[ "$(grep -c '^launch Firefox' "$STUB_LOG")" -eq 1 ]
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" TestGroup
	! stub_called '^launch' || false
	[[ $output == *"already open"* ]]
}

@test "--force reopens a group whose window is still open" {
	run "${BASH:-bash}" "$cmd" TestGroup
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" TestGroup --force
	stub_called '^launch Firefox'
}

@test "--no-menu --instances N opens only the missing windows" {
	stub_window 50 org.mozilla.firefox 1 Firefox "Existing"
	run "${BASH:-bash}" "$cmd" --no-menu --instances 3
	[ "$status" -eq 0 ]
	[ "$(grep -c '^launch Firefox -new-window' "$STUB_LOG")" -eq 2 ]
}

@test "an unknown group fails, a search opens Google" {
	run "${BASH:-bash}" "$cmd" NoSuchGroupAnywhere
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" --search dotfiles on macos
	stub_wait_for '^launch Firefox -new-window https://www\.google\.com/search\?q=dotfiles\+on\+macos'
}

@test "Safari: a group opens as one scripted window, and a rerun finds its URLs in the tabs and skips it" {
	run "${BASH:-bash}" "$cmd" TestGroup --browser Safari
	[ "$status" -eq 0 ]
	stub_called '^osascript .* - open com\.apple\.Safari https://one\.example/ https://two\.example/$'
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" TestGroup --browser Safari
	[ "$status" -eq 0 ]
	[[ $output == *"already open (Safari window 1)"* ]]
	! stub_called ' - open ' || false
}

@test "Safari: a redirect deeper into the site still counts, a window holding only some of the URLs does not" {
	echo com.apple.Safari >>"$STUB_RUNNING"
	printf 'com.apple.Safari\t1\thttps://www.one.example/deeper/page\tOne\ncom.apple.Safari\t2\thttps://two.example\tTwo\n' >"$STUB_TABS"
	run "${BASH:-bash}" "$cmd" TestGroup --browser Safari
	stub_called ' - open com\.apple\.Safari '
	printf 'com.apple.Safari\t1\thttps://www.one.example/deeper/page\tOne\ncom.apple.Safari\t1\thttps://two.example\tTwo\n' >"$STUB_TABS"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" TestGroup --browser Safari
	[[ $output == *"already open (Safari window 1)"* ]]
	! stub_called ' - open ' || false
}

@test "Safari: --private warns and opens a normal window" {
	run "${BASH:-bash}" "$cmd" TestGroup --browser Safari --private
	[ "$status" -eq 0 ]
	[[ $output == *"cannot open a private window by script"* ]]
	stub_called ' - open com\.apple\.Safari https://one\.example/ https://two\.example/$'
}

@test "Safari without Automation: the open fails at once with the permission named" {
	touch "$BATS_TEST_TMPDIR/automation-refused"
	run "${BASH:-bash}" "$cmd" TestGroup --browser Safari
	[ "$status" -ne 0 ]
	[[ $output == *"Privacy & Security > Automation"* ]]
	[[ $output == *"Could not open [TestGroup] in Safari"* ]]
}

@test "a Windows-style -Override opens an open group again, as --force does" {
	run "${BASH:-bash}" "$cmd" TestGroup
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" TestGroup -Override
	[ "$status" -eq 0 ]
	stub_called '^launch Firefox'
}

@test "a comma list names several groups; an unknown flag opens nothing" {
	printf '\n[Second]\nThree https://three.example/\n' >>"$FOUNDATION_CONFIG_DIR/browser-groups.conf"
	run "${BASH:-bash}" "$cmd" -Groups TestGroup,Second
	[ "$status" -eq 0 ]
	stub_wait_for '^launch Firefox https://one\.example/ https://two\.example/'
	stub_wait_for 'https://three\.example/'
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" TestGroup --forse
	[ "$status" -eq 1 ]
	! stub_called '^launch' || false
}

@test "the menu is the group tree: a nested index path opens one named URL, a group name the whole group" {
	printf '4.2\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"[4] TestGroup"* ]]
	[[ $output == *"[4.2] Two"* ]]
	stub_wait_for '^launch Firefox .*https://two\.example/$'
	! stub_called 'one\.example' || false
	: >"$STUB_LOG"
	printf 'testgroup\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd" --force
	stub_wait_for '^launch Firefox https://one\.example/ https://two\.example/'
}

@test "an index path given as a group is that entry of the menu tree, as -Groups 4.2 does on Windows" {
	run "${BASH:-bash}" "$cmd" 4.2
	[ "$status" -eq 0 ]
	stub_wait_for '^launch Firefox .*https://two\.example/$'
	! stub_called 'one\.example' || false
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" 4 --force
	[ "$status" -eq 0 ]
	stub_wait_for '^launch Firefox https://one\.example/ https://two\.example/'
}

@test "--private with a group warns and opens it in a normal window, as on Windows" {
	run "${BASH:-bash}" "$cmd" TestGroup --private
	[ "$status" -eq 0 ]
	[[ $output == *"Groups cannot be opened in private mode"* ]]
	stub_called '^launch Firefox https://one\.example/ https://two\.example/'
	! stub_called '-private-window' || false
}

@test "a search encodes every reserved character, as UrlEncode does: c++ stays c++" {
	run "${BASH:-bash}" "$cmd" --search c++ "templates?" é
	[ "$status" -eq 0 ]
	stub_wait_for 'search\?q=c%2B%2B\+templates%3F\+%C3%A9$'
}

@test "--no-menu --instances 2 --alongside opens two new windows next to one already open" {
	stub_window 50 org.mozilla.firefox 1 Firefox "Existing"
	run "${BASH:-bash}" "$cmd" --no-menu --instances 2 --alongside
	[ "$status" -eq 0 ]
	stub_wait_for '^launch Firefox -new-window'
	sleep 0.3
	[ "$(grep -c '^launch Firefox -new-window' "$STUB_LOG")" -eq 2 ]
}

@test "--alongside reopens a group whose window is still open" {
	run "${BASH:-bash}" "$cmd" TestGroup
	stub_wait_for '^launch Firefox'
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" TestGroup --alongside
	[ "$status" -eq 0 ]
	[[ $output != *"already open"* ]]
	stub_wait_for '^launch Firefox https://one\.example/ https://two\.example/'
}

@test "a cold start polls for the first window before the next launch, a warm start does not" {
	# A browser whose windows never appear: the gate polls its whole budget.
	printf '#!/bin/sh\necho "launch Firefox $*" >>"$STUB_LOG"\n' >"$STUB_BIN/launch-Firefox"
	export FOUNDATION_BROWSER_WINDOW_POLLS=3
	run "${BASH:-bash}" "$cmd" --no-menu --instances 2
	[ "$status" -eq 0 ]
	cold=$(grep -c '^aerospace list-windows' "$STUB_LOG")
	: >"$STUB_LOG"
	stub_window 50 org.mozilla.firefox 1 Firefox "Existing"
	run "${BASH:-bash}" "$cmd" --no-menu --instances 3
	[ "$status" -eq 0 ]
	warm=$(grep -c '^aerospace list-windows' "$STUB_LOG")
	[ $((cold - warm)) -eq 3 ]
}

@test "an empty Enter in the menu opens one plain browser window" {
	printf '\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_wait_for '^launch Firefox -new-window$'
	sleep 0.3
	[ "$(grep -c '^launch' "$STUB_LOG")" -eq 1 ]
}

# The windows a workspace open leaves alone (Open-Workspace writes them to the run directory).
protect() { # ID...
	export FOUNDATION_RUN_DIR=$BATS_TEST_TMPDIR/run
	mkdir -p "$FOUNDATION_RUN_DIR"
	printf '%s\n' "$@" >"$FOUNDATION_RUN_DIR/protected"
}

@test "--no-menu --instances does not count a window of a workspace the open leaves alone" {
	stub_window 50 org.mozilla.firefox 1 Firefox "Existing"
	protect 50
	run "${BASH:-bash}" "$cmd" --no-menu --instances 2
	[ "$status" -eq 0 ]
	stub_wait_for '^launch Firefox -new-window'
	sleep 0.3
	[ "$(grep -c '^launch Firefox -new-window' "$STUB_LOG")" -eq 2 ]
}

@test "a group open only in a protected window opens again, in Firefox and in Safari" {
	run "${BASH:-bash}" "$cmd" TestGroup
	stub_wait_for '^launch Firefox'
	protect "$(cut -d'|' -f1 "$STUB_WINDOWS" | tail -n 1)"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" TestGroup
	[[ $output != *"already open"* ]]
	stub_wait_for '^launch Firefox https://one\.example/'
	# Safari: the scripted window's tab title begins the protected window's title.
	echo com.apple.Safari >>"$STUB_RUNNING"
	printf 'com.apple.Safari\t1\thttps://one.example/\tOne\ncom.apple.Safari\t1\thttps://two.example/\tTwo\n' >"$STUB_TABS"
	stub_window 60 com.apple.Safari 2 Safari "One"
	protect 60
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" TestGroup --browser Safari
	stub_called ' - open com\.apple\.Safari '
}

@test "a scripted window that could be a protected or an unprotected one still counts as open" {
	echo com.apple.Safari >>"$STUB_RUNNING"
	printf 'com.apple.Safari\t1\thttps://one.example/\tOne\ncom.apple.Safari\t1\thttps://two.example/\tTwo\n' >"$STUB_TABS"
	stub_window 60 com.apple.Safari 2 Safari "One"
	stub_window 61 com.apple.Safari 1 Safari "Two"
	protect 60
	run "${BASH:-bash}" "$cmd" TestGroup --browser Safari
	[[ $output == *"already open"* ]]
	! stub_called ' - open ' || false
}
