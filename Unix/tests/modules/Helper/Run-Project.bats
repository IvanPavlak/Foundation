#!/usr/bin/env bats
# Run-Project (rp) against the WezTerm and docker stand-ins: the project's docker targets come up
# first, then each runnable tab opens and gets its run command typed in; a rerun closes the old
# tabs (or reuses this shell's), a Docker failure skips the project, Enter at the menu runs the
# first and a menu number names a project.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	stub_config
	mkdir -p "$BATS_TEST_TMPDIR/demo/api" "$BATS_TEST_TMPDIR/demo/root"
	touch "$BATS_TEST_TMPDIR/demo/root/compose.yaml"
	printf '\n[Demo]\npath ROOT %s/demo/root\npath API %s/demo/api\ntab API\nrun API dnr\ndocker ROOT\n' "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR" >>"$FOUNDATION_CONFIG_DIR/projects.conf"
	cmd=$UNIX_DIR/modules/Helper/bin/Run-Project
}

@test "docker first, then the run command is typed into the project's tab" {
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called '^docker compose up -d'
	stub_called "spawn .*--cwd $BATS_TEST_TMPDIR/demo/api"
	stub_called 'send-text --pane-id 700 --no-paste dnr'
	docker_line=$(grep -n '^docker compose' "$STUB_LOG" | head -1 | cut -d: -f1)
	spawn_line=$(grep -n 'spawn' "$STUB_LOG" | head -1 | cut -d: -f1)
	[ "$docker_line" -lt "$spawn_line" ]
}

@test "a number names that entry of the menu of runnable projects, as -Project 2 does on Windows" {
	foundation_load config project
	n=$(project_runnable | grep -nx Demo | cut -d: -f1)
	run "${BASH:-bash}" "$cmd" "$n" --skip Docker
	[ "$status" -eq 0 ]
	stub_called 'send-text --pane-id 700 --no-paste dnr'
}

@test "--skip Docker leaves the containers alone" {
	run "${BASH:-bash}" "$cmd" Demo --skip Docker
	! stub_called '^docker' || false
	stub_called 'send-text --pane-id 700 --no-paste dnr'
}

@test "--skip wins over --include, with a warning, as on Windows" {
	run "${BASH:-bash}" "$cmd" Demo --include Docker --skip Docker
	[ "$status" -eq 0 ]
	! stub_called '^docker' || false
	[[ $output == *"Step [Docker] is in both --skip and --include"* ]]
}

@test "projects.conf turns the Docker step off, --include turns it back on" {
	printf 'step Docker off\n' >>"$FOUNDATION_CONFIG_DIR/projects.local.conf"
	run "${BASH:-bash}" "$cmd" Demo
	! stub_called '^docker' || false
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Demo -Include Docker
	stub_called '^docker compose up -d'
}

@test "an unknown step name or flag stops it before anything runs" {
	run "${BASH:-bash}" "$cmd" Demo --skip Dokcer
	[ "$status" -eq 1 ]
	[[ $output == *"Unknown step [Dokcer]"* ]]
	[ ! -s "$STUB_LOG" ]
	run "${BASH:-bash}" "$cmd" Demo --bogus
	[ "$status" -eq 1 ]
	[ ! -s "$STUB_LOG" ]
}

# Demo with two database-provider stacks next to its own compose folder.
providers() {
	touch "$BATS_TEST_TMPDIR/pg.yml" "$BATS_TEST_TMPDIR/ora.yml"
	printf 'stack Pg %s/pg.yml\nstack Ora %s/ora.yml\n' "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR" >>"$FOUNDATION_CONFIG_DIR/docker.conf"
	printf 'docker Pg\ndocker Ora\n' >>"$FOUNDATION_CONFIG_DIR/projects.conf"
}

@test "of several database-provider stacks only the one --database-provider names starts" {
	providers
	run "${BASH:-bash}" "$cmd" Demo --database-provider ora
	[ "$status" -eq 0 ]
	stub_called "^docker compose -f $BATS_TEST_TMPDIR/ora\.yml up -d"
	! stub_called 'pg\.yml' || false
	# The project's own compose folder still comes up.
	stub_called '^docker compose up -d$'
	run "${BASH:-bash}" "$cmd" Demo --database-provider Oracle12
	[ "$status" -eq 1 ]
	[[ $output == *"has no database provider [Oracle12] (its stacks: Pg Ora)"* ]]
}

@test "without --database-provider a menu picks the stack, Enter takes the first" {
	providers
	printf '\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called "^docker compose -f $BATS_TEST_TMPDIR/pg\.yml up -d"
	! stub_called 'ora\.yml' || false
	: >"$STUB_LOG"
	printf '2\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd" Demo
	stub_called "^docker compose -f $BATS_TEST_TMPDIR/ora\.yml up -d"
	! stub_called 'pg\.yml' || false
}

@test "running a project again closes its open tabs first, as on Windows" {
	echo '[{"window_id":3,"tab_id":9,"pane_id":5,"is_active":true,"tab_title":"Demo.API","title":"zsh","cwd":"file:///x"}]' >"$STUB_PANES"
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	stub_called 'kill-pane --pane-id 5$'
	kill_line=$(grep -n 'kill-pane' "$STUB_LOG" | head -1 | cut -d: -f1)
	spawn_line=$(grep -n 'spawn' "$STUB_LOG" | head -1 | cut -d: -f1)
	[ "$kill_line" -lt "$spawn_line" ]
}

@test "run from one of the project's own tabs, that tab is reused and gets its run command" {
	echo '[{"window_id":3,"tab_id":9,"pane_id":5,"is_active":true,"tab_title":"Demo.API","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys005"}]' >"$STUB_PANES"
	export WEZTERM_PANE=5 STUB_TTY=ttys005
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 0 ]
	! stub_called 'spawn' || false
	! stub_called 'kill-pane' || false
	stub_called 'send-text --pane-id 5 --no-paste dnr'
}

@test "a Docker target that cannot come up skips the project: no tab opens" {
	touch "$BATS_TEST_TMPDIR/compose-fails"
	run "${BASH:-bash}" "$cmd" Demo
	[ "$status" -eq 1 ]
	stub_called '^docker compose up -d'
	! stub_called 'spawn' || false
	! stub_called 'send-text' || false
	[[ $output == *"Skipping [Demo]"* ]]
}

@test "an unknown project fails without typing anything" {
	run "${BASH:-bash}" "$cmd" NoSuchProjectAnywhere
	[ "$status" -eq 1 ]
	! stub_called 'spawn' || false
	! stub_called 'send-text' || false
}

@test "the project menu: Enter runs the first runnable project, an answer picks another" {
	printf '\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called 'send-text --pane-id 700 --no-paste npm run dev'
	! stub_called 'no-paste dnr' || false
	: >"$STUB_LOG"
	printf '2\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called 'send-text --pane-id 700 --no-paste dnr'
	! stub_called 'npm run dev' || false
}
