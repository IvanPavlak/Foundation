#!/usr/bin/env bats
# Open-Docker against docker / open / pgrep / osascript stand-ins: a running Docker Desktop is a
# warning and left alone, a stopped one is started and not waited for (as on Windows), a missing
# app fails, the daemon wait of docker_start (Start-Containers, Docker-Cleanup) still times out,
# and --stop stops the containers and quits Docker Desktop only while it runs.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	copy_fixture_config
	# docker info answers only while the daemon is "up"; open -a Docker brings it up unless
	# docker-fails exists. docker ps -q reports two containers.
	cat >"$STUB_BIN/docker" <<'SH'
#!/bin/sh
echo "docker $*" >>"$STUB_LOG"
case $1 in
	info) [ -f "$BATS_TEST_TMPDIR/docker-up" ] || exit 1 ;;
	ps) printf 'abc\ndef\n' ;;
esac
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
	cmd=$UNIX_DIR/modules/Application/bin/Open-Docker
}

# pgrep stand-in: the Docker backend runs, the Desktop process is gone (so the quit wait ends
# at once and nothing is ever killed).
docker_desktop_running() {
	printf '#!/bin/sh\necho "pgrep $*" >>"$STUB_LOG"\ncase "$*" in *com.docker.backend*) exit 0 ;; esac\nexit 1\n' >"$STUB_BIN/pgrep"
}

@test "a running Docker Desktop is a warning and is not started again" {
	touch "$BATS_TEST_TMPDIR/docker-up"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Docker Desktop is already running!"* ]]
	! stub_called '^open' || false
	: >"$STUB_LOG"
	rm "$BATS_TEST_TMPDIR/docker-up"
	docker_desktop_running
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"already running"* ]]
	! stub_called '^open' || false
}

@test "a stopped Docker Desktop is started in the background and not waited for" {
	touch "$BATS_TEST_TMPDIR/docker-fails"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^open -g -a Docker$'
	[[ $output == *"Docker Desktop opened!"* ]]
	# One look whether it already runs, no polling afterwards.
	[ "$(grep -c '^docker info' "$STUB_LOG")" -eq 1 ]
}

@test "Docker Desktop outside /Applications is found by its bundle id" {
	export FOUNDATION_DOCKER_APP=$BATS_TEST_TMPDIR/NoSuch.app
	# Spotlight (the mdfind stand-in) knows the bundle.
	echo com.docker.docker >"$STUB_INSTALLED"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called "^mdfind kMDItemCFBundleIdentifier == 'com.docker.docker'$"
	stub_called '^open -g -a Docker$'
}

@test "fails without Docker Desktop installed" {
	export FOUNDATION_DOCKER_APP=$BATS_TEST_TMPDIR/NoSuch.app
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	! stub_called '^open' || false
}

@test "docker_start, the DockerWizard wait, fails when the daemon does not answer in time" {
	touch "$BATS_TEST_TMPDIR/docker-fails"
	# The compose file exists: Start-Containers checks it before it starts Docker Desktop.
	touch "$BATS_TEST_TMPDIR/alpha.yml"
	printf 'stack Alpha %s/alpha.yml\ntimeout start 0\ntimeout stop 0\n' "$BATS_TEST_TMPDIR" >"$FOUNDATION_CONFIG_DIR/docker.conf"
	run "${BASH:-bash}" "$UNIX_DIR/modules/Workflow/bin/Start-Containers" Alpha
	[ "$status" -eq 1 ]
	stub_called '^open -g -a Docker$'
}

@test "--stop does nothing while Docker Desktop is not running" {
	run "${BASH:-bash}" "$cmd" --stop
	[ "$status" -eq 0 ]
	! stub_called '^docker ' || false
	! stub_called '^osascript' || false
}

@test "-Stop stops the running containers and quits Docker Desktop" {
	docker_desktop_running
	touch "$BATS_TEST_TMPDIR/docker-up"
	run "${BASH:-bash}" "$cmd" -Stop
	[ "$status" -eq 0 ]
	stub_called '^docker stop abc def$'
	stub_called "^osascript -e quit app \"Docker\"$"
	! stub_called '^open' || false
}

@test "--stop with the daemon down still quits Docker Desktop, stopping no container" {
	docker_desktop_running
	run "${BASH:-bash}" "$cmd" --stop
	[ "$status" -eq 0 ]
	! stub_called '^docker (ps|stop)' || false
	stub_called '^osascript -e quit app "Docker"$'
}

@test "a missing timeout line waits as long as the base docker.conf line: start 180, stop 60" {
	foundation_load docker
	printf 'stack Alpha alpha.yml\n' >"$FOUNDATION_CONFIG_DIR/docker.conf"
	[ "$(docker_timeout start)" = 180 ]
	[ "$(docker_timeout stop)" = 60 ]
	printf 'timeout stop 7\n' >"$FOUNDATION_CONFIG_DIR/docker.local.conf"
	[ "$(docker_timeout stop)" = 7 ]
	[ "$(docker_timeout start)" = 180 ]
}

@test "a relative stack file resolves under docker.conf's directory, Docker without the line" {
	foundation_load docker
	printf 'stack Alpha alpha.yml\nstack Beta /abs/beta.yml\n' >"$FOUNDATION_CONFIG_DIR/docker.conf"
	[ "$(docker_stack_file Alpha)" = "$DOTFILES_ROOT/Docker/alpha.yml" ]
	printf 'directory Compose/Files\n' >"$FOUNDATION_CONFIG_DIR/docker.local.conf"
	[ "$(docker_stack_file Alpha)" = "$DOTFILES_ROOT/Compose/Files/alpha.yml" ]
	printf 'directory ~/compose\n' >"$FOUNDATION_CONFIG_DIR/docker.local.conf"
	[ "$(docker_stack_file alpha)" = "$HOME/compose/alpha.yml" ]
	[ "$(docker_stack_file Beta)" = /abs/beta.yml ]
}
