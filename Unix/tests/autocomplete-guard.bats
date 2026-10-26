#!/usr/bin/env bats
# Unix/shell/autocomplete-guard.zsh, the time limit on zsh-autocomplete's completion worker: a
# worker that outlives the limit is killed with its zpty helper and what the helper forked; one
# that ends in time keeps its output and nothing is killed; without the plugin nothing is wrapped.
# The plugin is a stand-in worker function in a bare zsh; the processes are its own sleeps.

# bats file_tags=integration
load helpers

setup() {
	setup_foundation
	command -v zsh >/dev/null 2>&1 || skip "zsh is not installed"
	guard=$UNIX_DIR/shell/autocomplete-guard.zsh
	pids=$BATS_TEST_TMPDIR/pids
	mkdir -p "$pids"
}

teardown() {
	local f
	for f in "$pids"/*; do
		[ -f "$f" ] && kill -KILL "$(cat "$f")" 2>/dev/null
	done
	return 0
}

# A bare zsh that defines WORKER as the plugin's worker function, sources the guard with a limit of
# LIMIT seconds (sourced twice, as a reload does), runs the worker in a subshell as the plugin
# does, then runs AFTER. Usage: run_guard LIMIT WORKER [AFTER]
run_guard() {
	run zsh -f -c '
		zmodload zsh/system zsh/zpty
		worker=$2
		.autocomplete:async:start-worker() { eval "$worker" }
		_foundation_autocomplete_limit=$1
		. "$4"; . "$4"
		( .autocomplete:async:start-worker )
		print "status=$?"
		eval "$3"
	' _ "$1" "$2" "${3:-}" "$guard" 3>&-
}

alive() {
	kill -0 "$(cat "$pids/$1")" 2>/dev/null
}

@test "a worker past the limit is killed with its zpty helper and what the helper forked" {
	run_guard 1 '
		print $sysparams[pid] >'"$pids"'/worker
		zpty HELPER "print \$sysparams[pid] >'"$pids"'/helper; sleep 60 & print \$! >'"$pids"'/forked; wait"
		sleep 60'
	[[ $output == *"status=137"* ]]
	sleep 1
	! alive worker || false
	! alive helper || false
	! alive forked || false
}

@test "a worker that ends in time keeps its output, and nothing is killed after the limit" {
	run_guard 1 'print completed' 'sleep 3; print alive'
	[ "$status" -eq 0 ]
	[[ $output == *"completed"* ]]
	[[ $output == *"status=0"* ]]
	[[ $output == *"alive"* ]]
}

@test "without the plugin's worker function nothing is wrapped" {
	run zsh -f -c '. "$1"; print -r -- ${+functions[.autocomplete:async:start-worker]} ${+functions[.foundation:autocomplete:start-worker]}' _ "$guard"
	[ "$status" -eq 0 ]
	[ "$output" = "0 0" ]
}
