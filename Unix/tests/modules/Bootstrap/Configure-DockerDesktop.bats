#!/usr/bin/env bats
# Configure-DockerDesktop with a stand-in settings-store.json in the test folder, the real plutil,
# and docker / open / pgrep / osascript stand-ins: without a usable cli-install line, without a
# settings file or with the mode already set nothing changes; otherwise the file is backed up and
# DockerBinInstallPath written, every other key kept; a running Docker Desktop is stopped first and
# started again after; --dry-run stops and writes nothing; one that will not stop is not changed.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	copy_fixture_config
	export FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/backups
	export FOUNDATION_DOCKER_SETTINGS=$BATS_TEST_TMPDIR/settings-store.json
	printf '{"AutoStart":false,"DockerBinInstallPath":"user","SettingsVersion":48}\n' >"$FOUNDATION_DOCKER_SETTINGS"
	printf 'cli-install system\n' >"$FOUNDATION_CONFIG_DIR/docker.local.conf"
	mkdir -p "$BATS_TEST_TMPDIR/Docker.app"
	export FOUNDATION_DOCKER_APP=$BATS_TEST_TMPDIR/Docker.app
	cmd=$UNIX_DIR/modules/Bootstrap/bin/Configure-DockerDesktop
}

# The mode in the stand-in settings file.
mode() {
	plutil -extract DockerBinInstallPath raw -o - "$FOUNDATION_DOCKER_SETTINGS"
}

# pgrep stand-in: Docker Desktop runs until `docker desktop stop` (the docker stand-in) ends it.
docker_desktop_running() {
	touch "$BATS_TEST_TMPDIR/docker-running"
	printf '#!/bin/sh\necho "pgrep $*" >>"$STUB_LOG"\n[ -f "$BATS_TEST_TMPDIR/docker-running" ]\n' >"$STUB_BIN/pgrep"
	cat >"$STUB_BIN/docker" <<'SH'
#!/bin/sh
echo "docker $*" >>"$STUB_LOG"
case "$*" in "desktop stop --timeout"*) rm -f "$BATS_TEST_TMPDIR/docker-running" ;; esac
exit 0
SH
	chmod +x "$STUB_BIN/pgrep" "$STUB_BIN/docker"
}

@test "user mode becomes system mode: backed up first, every other key kept, Docker Desktop not running is not started" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(mode)" = system ]
	[ "$(plutil -extract SettingsVersion raw -o - "$FOUNDATION_DOCKER_SETTINGS")" = 48 ]
	[ "$(plutil -extract AutoStart raw -o - "$FOUNDATION_DOCKER_SETTINGS")" = false ]
	backup=$(find "$FOUNDATION_BACKUP_ROOT/System/DockerDesktop" -type f -name settings-store.json)
	[ "$(plutil -extract DockerBinInstallPath raw -o - "$backup")" = user ]
	! stub_called '^docker desktop stop' || false
	! stub_called '^open' || false
	[[ $output == *"asks for the administrator password at its next start"* ]]
}

@test "a running Docker Desktop is stopped cleanly before the write and started again after" {
	docker_desktop_running
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(mode)" = system ]
	stub_called '^docker desktop stop --timeout 5$'
	stub_called '^open -g -a Docker$'
	[ "$(grep -n '^docker desktop stop --timeout ' "$STUB_LOG" | cut -d: -f1)" -lt "$(grep -n '^open -g -a Docker$' "$STUB_LOG" | cut -d: -f1)" ]
}

@test "a Docker Desktop that does not quit is left with its settings unchanged" {
	# Running for good: the stop timeout of 0 kills at once, and the kill stand-in ends nothing.
	touch "$BATS_TEST_TMPDIR/docker-running"
	printf '#!/bin/sh\necho "pgrep $*" >>"$STUB_LOG"\nexit 0\n' >"$STUB_BIN/pgrep"
	printf 'cli-install system\ntimeout stop 0\n' >"$FOUNDATION_CONFIG_DIR/docker.local.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[ "$(mode)" = user ]
	[ ! -e "$FOUNDATION_BACKUP_ROOT" ]
}

@test "the mode already set, no cli-install line or an unknown value change nothing" {
	printf 'cli-install USER\n' >"$FOUNDATION_CONFIG_DIR/docker.local.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"already installs its tools in user mode"* ]]
	: >"$FOUNDATION_CONFIG_DIR/docker.local.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"No cli-install line"* ]]
	printf 'cli-install global\n' >"$FOUNDATION_CONFIG_DIR/docker.local.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(mode)" = user ]
	[ ! -e "$FOUNDATION_BACKUP_ROOT" ]
}

@test "a Docker Desktop that never ran (no settings file) is a warning and nothing is written" {
	rm "$FOUNDATION_DOCKER_SETTINGS"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"start it once"* ]]
	[ ! -e "$FOUNDATION_DOCKER_SETTINGS" ]
	[ ! -e "$FOUNDATION_BACKUP_ROOT" ]
}

@test "--dry-run says what would change, stopping and writing nothing" {
	docker_desktop_running
	run "${BASH:-bash}" "$cmd" --dry-run
	[ "$status" -eq 0 ]
	[[ $output == *"set DockerBinInstallPath [user] to [system]"*"stopping and restarting Docker Desktop"* ]]
	[ "$(mode)" = user ]
	! stub_called '^docker desktop stop' || false
	[ ! -e "$FOUNDATION_BACKUP_ROOT" ]
}

@test "--backup-root puts the backup under that folder; an unknown argument changes nothing" {
	run "${BASH:-bash}" "$cmd" --backup-root "$BATS_TEST_TMPDIR/elsewhere"
	[ "$status" -eq 0 ]
	[ -n "$(find "$BATS_TEST_TMPDIR/elsewhere/System/DockerDesktop" -type f -name settings-store.json)" ]
	printf '{"DockerBinInstallPath":"user"}\n' >"$FOUNDATION_DOCKER_SETTINGS"
	run "${BASH:-bash}" "$cmd" --system
	[ "$status" -eq 1 ]
	[ "$(mode)" = user ]
}
