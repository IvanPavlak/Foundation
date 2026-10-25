#!/usr/bin/env bats
# Open-SecureBrowser against the platform and browser stand-ins: Tor Browser (FOUNDATION_TOR_APP stands
# in for its fixed path, the mdfind stand-in for Spotlight) opens with the URLs; without it the default browser opens a private window
# with its own private flag, started the way Open-Browser starts it (launch=open through
# LaunchServices, launch=script through the scripting driver), and a default browser without a
# binary fails.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	stub_config
	printf '\napp TorBrowser org.torproject.torbrowser\n' >>"$FOUNDATION_CONFIG_DIR/apps.conf"
	# Not installed unless a test creates the folder.
	export FOUNDATION_TOR_APP="$BATS_TEST_TMPDIR/Tor Browser.app"
	cmd=$UNIX_DIR/modules/Application/bin/Open-SecureBrowser
}

@test "Tor Browser opens with the given URLs" {
	mkdir -p "$FOUNDATION_TOR_APP"
	run "${BASH:-bash}" "$cmd" https://a.example/ https://b.example/
	[ "$status" -eq 0 ]
	stub_called '^open -b org\.torproject\.torbrowser --args https://a\.example/ https://b\.example/$'
	! stub_called '^launch' || false
}

@test "Tor Browser opens on its own without URLs" {
	mkdir -p "$FOUNDATION_TOR_APP"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^open -b org\.torproject\.torbrowser$'
}

@test "Tor Browser outside /Applications is found by its bundle id" {
	# Spotlight (the mdfind stand-in) knows the bundle; the fixed path does not exist.
	echo org.torproject.torbrowser >"$STUB_INSTALLED"
	run "${BASH:-bash}" "$cmd" https://a.example/
	[ "$status" -eq 0 ]
	stub_called '^open -b org\.torproject\.torbrowser --args https://a\.example/$'
	! stub_called '^launch' || false
}

@test "without Tor Browser the default browser opens a private window" {
	run "${BASH:-bash}" "$cmd" https://a.example/
	[ "$status" -eq 0 ]
	stub_wait_for '^launch Firefox -private-window https://a\.example/$'
	! stub_called '^open -b' || false
}

@test "the private flag is the default browser's own" {
	printf 'default-browser Chrome\n' >>"$FOUNDATION_CONFIG_DIR/apps.conf"
	run "${BASH:-bash}" "$cmd" https://a.example/
	[ "$status" -eq 0 ]
	stub_wait_for '^launch Chrome --incognito https://a\.example/$'
}

@test "a browser without a configured private flag gets --private-window" {
	printf 'app Plain com.example.plain %s\ndefault-browser Plain\n' "$STUB_BIN/launch-Firefox" >>"$FOUNDATION_CONFIG_DIR/apps.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_wait_for '^launch Firefox --private-window$'
}

@test "a default browser without a binary fails and launches nothing" {
	printf 'default-browser Obsidian\n' >>"$FOUNDATION_CONFIG_DIR/apps.conf"
	run "${BASH:-bash}" "$cmd" https://a.example/
	[ "$status" -eq 1 ]
	! stub_called '^(launch|open)' || false
}

@test "without Tor Browser a launch=open default browser starts through LaunchServices" {
	mkdir -p "$BATS_TEST_TMPDIR/Fake.app/Contents/MacOS"
	printf '#!/bin/sh\necho "launch Fake $*" >>"$STUB_LOG"\n' >"$BATS_TEST_TMPDIR/Fake.app/Contents/MacOS/fake"
	chmod +x "$BATS_TEST_TMPDIR/Fake.app/Contents/MacOS/fake"
	printf 'app Fake com.example.fake %s\nbrowser Fake --new-window --incognito launch=open\ndefault-browser Fake\n' "$BATS_TEST_TMPDIR/Fake.app/Contents/MacOS/fake" >>"$FOUNDATION_CONFIG_DIR/apps.conf"
	run "${BASH:-bash}" "$cmd" https://a.example/
	[ "$status" -eq 0 ]
	stub_called '^open -na .*/Fake\.app --args --incognito https://a\.example/$'
	! stub_called '^launch Fake' || false
}

@test "without Tor Browser a launch=script default browser opens a scripted window and warns" {
	printf 'default-browser Safari\n' >>"$FOUNDATION_CONFIG_DIR/apps.conf"
	run "${BASH:-bash}" "$cmd" https://a.example/
	[ "$status" -eq 0 ]
	[[ $output == *"cannot open a private window by script"* ]]
	stub_called '^osascript .* - open com\.apple\.Safari https://a\.example/$'
	! stub_called '^(launch|open -na)' || false
}
