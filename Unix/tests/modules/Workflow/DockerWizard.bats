#!/usr/bin/env bats
# DockerWizard against docker / open / pgrep / osascript stand-ins: it starts Docker Desktop and
# waits for the daemon, brings up an explicit compose file or the first compose file of a folder,
# fails when a compose source was asked for and is missing, and --stop quits Docker Desktop.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	copy_fixture_config
	# docker info answers once open -a Docker has brought the daemon up.
	cat >"$STUB_BIN/docker" <<'SH'
#!/bin/sh
echo "docker $*" >>"$STUB_LOG"
case $1 in info) [ -f "$BATS_TEST_TMPDIR/docker-up" ] || exit 1 ;; esac
exit 0
SH
	cat >"$STUB_BIN/open" <<'SH'
#!/bin/sh
echo "open $*" >>"$STUB_LOG"
case " $* " in *" -a Docker "*) touch "$BATS_TEST_TMPDIR/docker-up" ;; esac
exit 0
SH
	chmod +x "$STUB_BIN/docker" "$STUB_BIN/open"
	mkdir -p "$BATS_TEST_TMPDIR/Docker.app" "$BATS_TEST_TMPDIR/app"
	export FOUNDATION_DOCKER_APP=$BATS_TEST_TMPDIR/Docker.app
	cmd=$UNIX_DIR/modules/Workflow/bin/DockerWizard
}

@test "a bare call starts Docker Desktop and waits for the daemon, nothing else" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^open -g -a Docker$'
	stub_called '^docker info'
	! stub_called '^docker compose' || false
}

@test "--compose-file-path brings that file up" {
	touch "$BATS_TEST_TMPDIR/app/my.yml"
	run "${BASH:-bash}" "$cmd" -ComposeFilePath "$BATS_TEST_TMPDIR/app/my.yml"
	[ "$status" -eq 0 ]
	stub_called "^docker compose -f $BATS_TEST_TMPDIR/app/my\.yml up -d$"
}

@test "--compose-project-path takes the first compose file in the order docker compose uses" {
	touch "$BATS_TEST_TMPDIR/app/docker-compose.yml" "$BATS_TEST_TMPDIR/app/compose.yml"
	run "${BASH:-bash}" "$cmd" --compose-project-path "$BATS_TEST_TMPDIR/app"
	[ "$status" -eq 0 ]
	stub_called "^docker compose -f $BATS_TEST_TMPDIR/app/compose\.yml up -d$"
}

@test "a compose source that does not resolve to a file fails after the daemon is up" {
	run "${BASH:-bash}" "$cmd" --compose-file-path "$BATS_TEST_TMPDIR/app/missing.yml"
	[ "$status" -eq 1 ]
	[[ $output == *"Docker Compose file not found"* ]]
	run "${BASH:-bash}" "$cmd" --compose-project-path "$BATS_TEST_TMPDIR/app"
	[ "$status" -eq 1 ]
	[[ $output == *"No Docker Compose file found in"* ]]
	! stub_called '^docker compose' || false
}

@test "--stop quits Docker Desktop and ignores the compose flags; an unknown flag touches nothing" {
	printf '#!/bin/sh\necho "pgrep $*" >>"$STUB_LOG"\ncase "$*" in *com.docker.backend*) exit 0 ;; esac\nexit 1\n' >"$STUB_BIN/pgrep"
	run "${BASH:-bash}" "$cmd" --stop --compose-file-path "$BATS_TEST_TMPDIR/app/my.yml"
	[ "$status" -eq 0 ]
	stub_called '^docker desktop stop --timeout 5$'
	! stub_called '^osascript' || false
	! stub_called '^docker compose' || false
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" --udpate
	[ "$status" -eq 1 ]
	! stub_called '^open' || false
}
