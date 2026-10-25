#!/usr/bin/env bats
# Docker-Cleanup against the stand-ins: selected actions run in configuration order after their
# previews and one confirmation, an empty preview skips its action, a failure does not stop the
# rest, and cleanup-start decides what happens while the daemon is down. The actions are plain
# shell lines that log to STUB_LOG, so nothing here reaches a real Docker.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	stub_config
	# docker info answers only while the daemon is "up"; open -a Docker brings it up.
	cat >"$STUB_BIN/docker" <<'SH'
#!/bin/sh
echo "docker $*" >>"$STUB_LOG"
[ "$1" = info ] && { [ -f "$BATS_TEST_TMPDIR/docker-up" ] || exit 1; }
exit 0
SH
	cat >"$STUB_BIN/open" <<'SH'
#!/bin/sh
echo "open $*" >>"$STUB_LOG"
case " $* " in *" -a Docker "*) [ -f "$BATS_TEST_TMPDIR/docker-fails" ] || touch "$BATS_TEST_TMPDIR/docker-up" ;; esac
exit 0
SH
	chmod +x "$STUB_BIN/docker" "$STUB_BIN/open"
	mkdir -p "$BATS_TEST_TMPDIR/Docker.app"
	export FOUNDATION_DOCKER_APP=$BATS_TEST_TMPDIR/Docker.app
	touch "$BATS_TEST_TMPDIR/docker-up"
	items=$BATS_TEST_TMPDIR/items
	mkdir -p "$items"
	printf 'web (nginx)\n' >"$items/a"
	printf 'img:latest\n' >"$items/b"
	: >"$items/c"
	cat >"$FOUNDATION_CONFIG_DIR/docker.conf" <<EOF
timeout start 2
cleanup Alpha :: echo "ran Alpha" >>"$STUB_LOG" :: Sure about Alpha?
cleanup-description Alpha :: Stops things.
cleanup-preview Alpha :: cat "$items/a"
cleanup Beta :: echo "ran Beta" >>"$STUB_LOG" :: Sure about Beta?
cleanup-preview Beta :: cat "$items/b"
cleanup Gamma :: echo "ran Gamma" >>"$STUB_LOG"
EOF
	cmd=$UNIX_DIR/modules/Workflow/bin/Docker-Cleanup
}

answers() {
	printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/answers"
	export FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers
}

ran() {
	grep -c "^ran " "$STUB_LOG" || true
}

@test "a confirmed action runs only after yes; Enter runs nothing" {
	answers ''
	run "${BASH:-bash}" "$cmd" Alpha
	[ "$status" -eq 0 ]
	[ "$(ran)" -eq 0 ]
	answers yes
	run "${BASH:-bash}" "$cmd" Alpha
	[ "$status" -eq 0 ]
	stub_called '^ran Alpha$'
}

@test "a single action asks its own message and shows its description and preview first" {
	answers yes
	run "${BASH:-bash}" "$cmd" alpha
	[[ "$output" == *"Alpha - Stops things."* ]]
	[[ "$output" == *"• web (nginx)"* ]]
	[[ "$output" == *"Sure about Alpha?"* ]]
}

@test "an action without a confirmation and without a preview runs straight away" {
	run "${BASH:-bash}" "$cmd" 3
	[ "$status" -eq 0 ]
	stub_called '^ran Gamma$'
}

@test "All runs every action that has something to do, in configuration order" {
	printf 'c-item\n' >"$items/c"
	answers yes
	run "${BASH:-bash}" "$cmd" all
	[ "$status" -eq 0 ]
	[ "$(grep '^ran ' "$STUB_LOG" | tr '\n' ' ')" = "ran Alpha ran Beta ran Gamma " ]
	[[ "$output" == *"run these 3 actions?"* ]]
}

@test "actions picked out of order still run in configuration order" {
	answers yes
	run "${BASH:-bash}" "$cmd" Beta 1
	[ "$status" -eq 0 ]
	[ "$(grep '^ran ' "$STUB_LOG" | tr '\n' ' ')" = "ran Alpha ran Beta " ]
}

@test "an empty preview skips its action and the rest still run" {
	cat >>"$FOUNDATION_CONFIG_DIR/docker.conf" <<EOF
cleanup-preview Gamma :: cat "$items/c"
EOF
	answers yes
	run "${BASH:-bash}" "$cmd" Alpha Gamma
	[ "$status" -eq 0 ]
	[[ "$output" == *"Gamma - nothing to do, skipped!"* ]]
	stub_called '^ran Alpha$'
	! stub_called '^ran Gamma$' || false
	# The one remaining action asks its own message, not the combined one.
	[[ "$output" == *"Sure about Alpha?"* ]]
}

@test "when every preview is empty nothing is asked and nothing runs" {
	: >"$items/a"
	: >"$items/b"
	answers yes
	run "${BASH:-bash}" "$cmd" Alpha Beta
	[ "$status" -eq 0 ]
	[[ "$output" == *"Nothing to do - nothing was touched!"* ]]
	[[ "$output" != *"Sure about"* ]]
	[ "$(ran)" -eq 0 ]
}

@test "a declined combined confirmation runs nothing" {
	answers no
	run "${BASH:-bash}" "$cmd" All
	[ "$status" -eq 0 ]
	[ "$(ran)" -eq 0 ]
}

@test "a failing action is reported, the later ones still run and the status is non-zero" {
	cat >"$FOUNDATION_CONFIG_DIR/docker.conf" <<EOF
cleanup Broken :: exit 3
cleanup Gamma :: echo "ran Gamma" >>"$STUB_LOG"
EOF
	run "${BASH:-bash}" "$cmd" All
	[ "$status" -ne 0 ]
	[[ "$output" == *"Broken failed with exit code [3]!"* ]]
	stub_called '^ran Gamma$'
}

@test "an unknown action fails before anything runs" {
	run "${BASH:-bash}" "$cmd" Alpha NoSuchAction
	[ "$status" -ne 0 ]
	[ "$(ran)" -eq 0 ]
}

@test "with the daemon down, an unknown action or flag fails before Docker is started" {
	rm "$BATS_TEST_TMPDIR/docker-up"
	printf 'cleanup-start always\n' >>"$FOUNDATION_CONFIG_DIR/docker.conf"
	run "${BASH:-bash}" "$cmd" Gamma NoSuchAction
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" Gamma --bogus-flag
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" -WhatIf Gamma
	[ "$status" -ne 0 ]
	! stub_called '^open' || false
	[ "$(ran)" -eq 0 ]
}

@test "the Windows -Action spelling selects, and -Verbose reaches the debug output" {
	run "${BASH:-bash}" "$cmd" -Action Gamma -Verbose
	[ "$status" -eq 0 ]
	stub_called '^ran Gamma$'
	[[ $output == *"[debug] [Docker-Cleanup] selected => Gamma"* ]]
}

@test "no cleanup lines is an error" {
	printf 'timeout start 2\n' >"$FOUNDATION_CONFIG_DIR/docker.conf"
	run "${BASH:-bash}" "$cmd" All
	[ "$status" -ne 0 ]
}

@test "daemon down, ask: Enter starts Docker and the cleanup goes on" {
	rm "$BATS_TEST_TMPDIR/docker-up"
	answers '' yes
	run "${BASH:-bash}" "$cmd" Alpha
	[ "$status" -eq 0 ]
	stub_called '^open -g -a Docker'
	stub_called '^ran Alpha$'
}

@test "daemon down, ask: no starts nothing and runs nothing" {
	rm "$BATS_TEST_TMPDIR/docker-up"
	answers n
	run "${BASH:-bash}" "$cmd" Gamma
	[ "$status" -eq 0 ]
	! stub_called '^open' || false
	[ "$(ran)" -eq 0 ]
}

@test "daemon down, an unknown start mode behaves like ask" {
	rm "$BATS_TEST_TMPDIR/docker-up"
	printf 'cleanup-start sometimes\n' >>"$FOUNDATION_CONFIG_DIR/docker.conf"
	answers n
	run "${BASH:-bash}" "$cmd" Gamma
	[[ "$output" == *"start it?"* ]]
	! stub_called '^open' || false
}

@test "daemon down, always: starts Docker without asking" {
	rm "$BATS_TEST_TMPDIR/docker-up"
	printf 'cleanup-start Always\n' >>"$FOUNDATION_CONFIG_DIR/docker.conf"
	run "${BASH:-bash}" "$cmd" Gamma
	[ "$status" -eq 0 ]
	[[ "$output" != *"start it?"* ]]
	stub_called '^open -g -a Docker'
	stub_called '^ran Gamma$'
}

@test "daemon down, never: warns and starts nothing" {
	rm "$BATS_TEST_TMPDIR/docker-up"
	printf 'cleanup-start never\n' >>"$FOUNDATION_CONFIG_DIR/docker.conf"
	run "${BASH:-bash}" "$cmd" Gamma
	[ "$status" -eq 0 ]
	[[ "$output" == *"Docker is not running!"* ]]
	! stub_called '^open' || false
	[ "$(ran)" -eq 0 ]
}

@test "daemon down and Docker never comes up: nothing runs" {
	rm "$BATS_TEST_TMPDIR/docker-up"
	touch "$BATS_TEST_TMPDIR/docker-fails"
	printf 'cleanup-start always\n' >>"$FOUNDATION_CONFIG_DIR/docker.conf"
	run "${BASH:-bash}" "$cmd" Gamma
	[ "$status" -ne 0 ]
	[ "$(ran)" -eq 0 ]
}

@test "without arguments and without a terminal the menu fails and nothing runs" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[ "$(ran)" -eq 0 ]
}

@test "daemon down, ask, and no terminal: Docker is not started and nothing runs" {
	rm "$BATS_TEST_TMPDIR/docker-up"
	run "${BASH:-bash}" "$cmd" Gamma
	[ "$status" -eq 0 ]
	[[ "$output" == *"no terminal to ask - nothing was touched"* ]]
	! stub_called '^open' || false
	[ "$(ran)" -eq 0 ]
}
