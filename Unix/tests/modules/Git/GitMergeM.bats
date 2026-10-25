#!/usr/bin/env bats
# GitMergeM (gmm): merges master into the current branch.

# bats file_tags=integration
load ../../helpers
load ../../git

setup() {
	setup_foundation
	git_sandbox
	cd "$REPO"
}

@test "the current branch gets master's new commit" {
	git switch -qc work
	git switch -q master
	echo later >other.txt
	git add other.txt
	git commit -qm "Later on master"
	git switch -q work
	run "${BASH:-bash}" "$bin/GitMergeM"
	[ "$status" -eq 0 ]
	[ "$(git branch --show-current)" = work ]
	[ -f other.txt ]
}

@test "a repository whose default branch is main merges main" {
	git branch -qm master main
	git switch -qc work
	git switch -q main
	echo later >other.txt
	git add other.txt
	git commit -qm "Later on main"
	git switch -q work
	run "${BASH:-bash}" "$bin/GitMergeM"
	[ "$status" -eq 0 ]
	[ -f other.txt ]
}

@test "with neither master nor main it fails and HEAD stays where it was" {
	git branch -qm master trunk
	git switch -qc work
	before=$(git rev-parse HEAD)
	run "${BASH:-bash}" "$bin/GitMergeM"
	[ "$status" -ne 0 ]
	[[ $output == *"Neither 'master' nor 'main' branch exists in this repository!"* ]]
	[ "$(git rev-parse HEAD)" = "$before" ]
	[ "$(git branch --show-current)" = work ]
}
