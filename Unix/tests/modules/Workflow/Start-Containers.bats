#!/usr/bin/env bats
# Start-Containers against a docker stand-in: which stacks run (the only one, the named ones or
# their menu numbers, the menu pick, sorted by name), up -d / stop / down per flag, Docker Desktop started only for an up
# and only once a compose file was found, and a missing stack or compose file failing without
# stopping the rest. Nothing here reaches a real Docker.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	copy_fixture_config
	# docker info answers only while the daemon is "up"; open -a Docker brings it up. compose up
	# fails while $BATS_TEST_TMPDIR/up-fails exists, compose ps prints a published port.
	cat >"$STUB_BIN/docker" <<'SH'
#!/bin/sh
echo "docker $*" >>"$STUB_LOG"
[ "$1" = info ] && { [ -f "$BATS_TEST_TMPDIR/docker-up" ] || exit 1; }
case "$*" in
	*" up -d") [ -f "$BATS_TEST_TMPDIR/up-fails" ] && exit 1 ;;
	*" ps "*) echo "db -> 0.0.0.0:5432->5432/tcp" ;;
esac
exit 0
SH
	cat >"$STUB_BIN/open" <<'SH'
#!/bin/sh
echo "open $*" >>"$STUB_LOG"
case " $* " in *" -a Docker "*) touch "$BATS_TEST_TMPDIR/docker-up" ;; esac
exit 0
SH
	chmod +x "$STUB_BIN/docker" "$STUB_BIN/open"
	mkdir -p "$BATS_TEST_TMPDIR/Docker.app"
	export FOUNDATION_DOCKER_APP=$BATS_TEST_TMPDIR/Docker.app
	touch "$BATS_TEST_TMPDIR/docker-up"
	stacks=$BATS_TEST_TMPDIR/stacks
	mkdir -p "$stacks"
	touch "$stacks/alpha.yml" "$stacks/beta.yml"
	printf 'timeout start 1\nstack Alpha %s/alpha.yml\n' "$stacks" >"$FOUNDATION_CONFIG_DIR/docker.conf"
	cmd=$UNIX_DIR/modules/Workflow/bin/Start-Containers
}

two_stacks() {
	printf 'stack Beta %s/beta.yml\n' "$stacks" >>"$FOUNDATION_CONFIG_DIR/docker.conf"
}

@test "the only configured stack comes up and its published ports are printed" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called "^docker compose -f $stacks/alpha.yml up -d$"
	[[ $output == *"db -> 0.0.0.0:5432"* ]]
	! stub_called '^open' || false
}

@test "named stacks come up, case-insensitively, and only those" {
	two_stacks
	run "${BASH:-bash}" "$cmd" beta
	[ "$status" -eq 0 ]
	stub_called "^docker compose -f $stacks/beta.yml up -d$"
	! stub_called 'alpha\.yml' || false
}

@test "a number names that entry of the menu, sorted by name, as -Name 2 does on Windows" {
	two_stacks
	run "${BASH:-bash}" "$cmd" 2
	[ "$status" -eq 0 ]
	stub_called "^docker compose -f $stacks/beta.yml up -d$"
	! stub_called 'alpha\.yml' || false
}

@test "several stacks and no name: the menu pick comes up" {
	two_stacks
	printf '2\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called "^docker compose -f $stacks/beta.yml up -d$"
	! stub_called 'alpha\.yml' || false
}

@test "several stacks, no name and no terminal: nothing runs" {
	two_stacks
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	! stub_called '^docker compose' || false
}

@test "--stop stops the containers, --stop --down removes them" {
	run "${BASH:-bash}" "$cmd" Alpha --stop
	[ "$status" -eq 0 ]
	stub_called "^docker compose -f $stacks/alpha.yml stop$"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Alpha --stop --down
	[ "$status" -eq 0 ]
	stub_called "^docker compose -f $stacks/alpha.yml down$"
	! stub_called ' stop$' || false
	! stub_called ' up -d$' || false
}

@test "--stop with the daemon down stops nothing and starts nothing" {
	rm "$BATS_TEST_TMPDIR/docker-up"
	run "${BASH:-bash}" "$cmd" --stop
	[ "$status" -eq 0 ]
	! stub_called '^docker compose' || false
	! stub_called '^open' || false
}

@test "the daemon down: Docker Desktop is started before the stack comes up" {
	rm "$BATS_TEST_TMPDIR/docker-up"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^open -g -a Docker'
	stub_called "^docker compose -f $stacks/alpha.yml up -d$"
}

@test "Docker Desktop not installed: nothing comes up" {
	rm "$BATS_TEST_TMPDIR/docker-up"
	export FOUNDATION_DOCKER_APP=$BATS_TEST_TMPDIR/NoSuchDocker.app
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	! stub_called '^open' || false
	! stub_called '^docker compose' || false
}

@test "an unknown stack fails while the named known one still comes up" {
	run "${BASH:-bash}" "$cmd" NoSuchStack Alpha
	[ "$status" -eq 1 ]
	stub_called "^docker compose -f $stacks/alpha.yml up -d$"
}

@test "a missing compose file fails that stack only" {
	two_stacks
	rm "$stacks/alpha.yml"
	run "${BASH:-bash}" "$cmd" Alpha Beta
	[ "$status" -eq 1 ]
	! stub_called 'alpha\.yml' || false
	stub_called "^docker compose -f $stacks/beta.yml up -d$"
}

@test "a missing compose file fails before Docker Desktop is started" {
	rm "$BATS_TEST_TMPDIR/docker-up" "$stacks/alpha.yml"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	! stub_called '^open' || false
	! stub_called '^docker compose' || false
}

@test "the menu lists the stacks sorted by name, not in file order" {
	printf 'timeout start 1\nstack Zeta %s/beta.yml\nstack alpha %s/alpha.yml\n' "$stacks" "$stacks" >"$FOUNDATION_CONFIG_DIR/docker.conf"
	printf '1\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called "^docker compose -f $stacks/alpha.yml up -d$"
	! stub_called 'beta\.yml' || false
}

@test "a failing compose up is a failure and prints no ports" {
	touch "$BATS_TEST_TMPDIR/up-fails"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	! stub_called ' ps ' || false
}

@test "no stack configured is an error" {
	printf 'timeout start 1\n' >"$FOUNDATION_CONFIG_DIR/docker.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	! stub_called '^docker compose' || false
}

@test "an overlay stack named like a base stack replaces it, and the menu lists the name once" {
	two_stacks
	touch "$stacks/gamma.yml"
	printf 'stack alpha %s/gamma.yml\n' "$stacks" >"$FOUNDATION_CONFIG_DIR/docker.local.conf"
	printf '1\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called "^docker compose -f $stacks/gamma.yml up -d$"
	! stub_called 'alpha\.yml' || false
	[ "$(printf '%s\n' "$output" | grep -ci '\] alpha$')" -eq 1 ]
}

@test "a comma list names several stacks; an unknown flag starts nothing" {
	two_stacks
	run "${BASH:-bash}" "$cmd" -Name Alpha,Beta
	[ "$status" -eq 0 ]
	stub_called "^docker compose -f $stacks/alpha.yml up -d$"
	stub_called "^docker compose -f $stacks/beta.yml up -d$"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Alpha --sotp
	[ "$status" -eq 1 ]
	! stub_called '^docker compose' || false
}
