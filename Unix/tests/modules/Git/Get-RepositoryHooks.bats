#!/usr/bin/env bats
# Get-RepositoryHooks against throwaway repositories (real git, user config never read): one line
# per repository line marked hooks=FOLDER with the state of its clone, the records of clones no
# longer marked, and nothing written anywhere.

# bats file_tags=integration
load ../../helpers
load ../../git

setup() {
	setup_foundation
	git_sandbox
	export FOUNDATION_CONFIG_DIR=$BATS_TEST_TMPDIR/config
	mkdir -p "$FOUNDATION_CONFIG_DIR"
	mkdir -p "$REPO/.githooks"
	printf '#!/bin/sh\nexit 0\n' >"$REPO/.githooks/pre-commit"
	chmod +x "$REPO/.githooks/pre-commit"
	git -C "$REPO" add .githooks
	git -C "$REPO" commit -qm "Hooks"
	STATE=$FOUNDATION_STATE_DIR/repository-hooks.state
}

# [Demo] with Repo = the sandbox clone and WORDS after its folder. Usage: hooks_conf [WORDS]
hooks_conf() { printf '[Demo]\nRepo  %s  %s %s\n' "$(origin_url Repo)" "$REPO" "${1:-}" >"$FOUNDATION_CONFIG_DIR/repositories.conf"; }
hooks() { run "${BASH:-bash}" "$bin/Get-RepositoryHooks" "$@"; }
# Everything a listing could have changed: the clone's configuration and the state folder.
fingerprint() {
	cat "$REPO/.git/config"
	ls -A "$FOUNDATION_STATE_DIR" 2>/dev/null
	cat "$STATE" 2>/dev/null
	return 0
}

@test "a marked repository is NotSet, then Active once its hooks path is the configured folder" {
	hooks_conf "hooks=.githooks"
	hooks
	[ "$status" -eq 0 ]
	[[ $output == *"[Repo] configured [.githooks], found [none] - NotSet"* ]]
	git -C "$REPO" config --local core.hooksPath .githooks
	hooks
	[ "$status" -eq 0 ]
	[[ $output == *"[Repo] configured [.githooks], found [.githooks] - Active"* ]]
	[[ $output != *"not executable"* ]]
}

@test "another value is Different, and a folder missing in the clone is MissingFolder" {
	git -C "$REPO" config --local core.hooksPath elsewhere
	hooks_conf "hooks=.githooks"
	hooks
	[[ $output == *"found [elsewhere] - Different"* ]]
	hooks_conf "hooks=nope"
	hooks
	[ "$status" -eq 0 ]
	[[ $output == *"configured [nope], found [elsewhere] - MissingFolder"* ]]
	hooks_conf "hooks=../outside"
	hooks
	[[ $output == *" - Invalid"* ]]
}

@test "a folder not on this machine, a line without a folder and a folder that is no repository are named" {
	mkdir -p "$BATS_TEST_TMPDIR/plain" "$REPO/sub"
	printf '[Demo]\nGone  %s  %s/gone hooks=.githooks\nNoDir  %s  hooks=.githooks\nPlain  %s  %s/plain hooks=.githooks\nSub  %s  %s/sub hooks=.githooks\n' \
		"$(origin_url Gone)" "$BATS_TEST_TMPDIR" "$(origin_url NoDir)" "$(origin_url Plain)" "$BATS_TEST_TMPDIR" "$(origin_url Sub)" "$REPO" >"$FOUNDATION_CONFIG_DIR/repositories.conf"
	hooks
	[ "$status" -eq 0 ]
	[[ $output == *"[Gone] "*" - NotCloned"* ]]
	[[ $output == *"[NoDir] "*" - NotConfigured"* ]]
	[[ $output == *"[Plain] "*" - NotARepository"* ]]
	[[ $output == *"[Sub] "*" - NotARepository"* ]]
	[ ! -e "$BATS_TEST_TMPDIR/gone" ]
}

@test "only marked lines are listed, each folder once, across every group" {
	git clone -q "$ORIGIN" "$BATS_TEST_TMPDIR/second" 2>/dev/null
	printf '[One]\nRepo  %s  %s hooks=.githooks\nSecond  %s  %s/second\n[Two]\nAgain  %s  %s hooks=.githooks\n' \
		"$(origin_url Repo)" "$REPO" "$(origin_url Second)" "$BATS_TEST_TMPDIR" "$(origin_url Again)" "$REPO" >"$FOUNDATION_CONFIG_DIR/repositories.conf"
	hooks
	[ "$status" -eq 0 ]
	[[ $output == *"[Repo] "* ]]
	[[ $output != *"[Second]"* ]]
	[[ $output != *"[Again]"* ]]
}

@test "an Active line names the hook files without the executable bit" {
	printf '#!/bin/sh\nexit 0\n' >"$REPO/.githooks/pre-push"
	git -C "$REPO" config --local core.hooksPath .githooks
	hooks_conf "hooks=.githooks"
	hooks
	[ "$status" -eq 0 ]
	[[ $output == *" - Active, not executable: pre-push"* ]]
	[ ! -x "$REPO/.githooks/pre-push" ]
}

@test "a clone an update set and whose line lost the mark is listed as Stale" {
	hooks_conf "hooks=.githooks"
	run "${BASH:-bash}" "$bin/Update-Repositories" --group Demo --quiet
	[ "$status" -eq 0 ]
	hooks
	[[ $output != *"Stale"* ]]
	hooks_conf
	hooks
	[ "$status" -eq 0 ]
	[[ $output == *"[$REPO] recorded [.githooks] - Stale"* ]]
	[[ $output != *"[Repo] configured"* ]]
}

@test "no marked line says so and still succeeds" {
	hooks_conf
	hooks
	[ "$status" -eq 0 ]
	[[ $output == *"hooks=FOLDER"* ]]
}

@test "it writes nothing: the clone's configuration and the state folder are as they were" {
	hooks_conf "hooks=.githooks"
	before=$(fingerprint)
	hooks
	[ "$(fingerprint)" = "$before" ]
	run "${BASH:-bash}" "$bin/Update-Repositories" --group Demo --quiet
	hooks_conf
	before=$(fingerprint)
	hooks
	[ "$(fingerprint)" = "$before" ]
}

@test "an argument it does not know is an error" {
	hooks_conf "hooks=.githooks"
	hooks --bogus-flag
	[ "$status" -ne 0 ]
	hooks extra
	[ "$status" -ne 0 ]
}
