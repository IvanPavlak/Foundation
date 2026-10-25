#!/usr/bin/env bats
# GitBranch (gb): lists branches with their last commit, or creates and switches to BRANCH.

# bats file_tags=integration
load ../../helpers
load ../../git

setup() {
	setup_foundation
	git_sandbox
	cd "$REPO"
}

@test "without a name it lists the branches with their last commit" {
	run "${BASH:-bash}" "$bin/GitBranch"
	[ "$status" -eq 0 ]
	[[ $output == *master* ]]
	[[ $output == *"First commit"* ]]
}

@test "with a name it creates the branch and stays on the current one, like Windows" {
	run "${BASH:-bash}" "$bin/GitBranch" feature/demo
	[ "$status" -eq 0 ]
	git show-ref --verify -q refs/heads/feature/demo
	[ "$(git branch --show-current)" = master ]
}

@test "the Windows -BranchName names the branch; an unknown flag creates nothing" {
	run "${BASH:-bash}" "$bin/GitBranch" -BranchName feature/named
	[ "$status" -eq 0 ]
	git show-ref --verify -q refs/heads/feature/named
	! git show-ref --verify -q refs/heads/-BranchName || false
	run "${BASH:-bash}" "$bin/GitBranch" --bogus feature/other
	[ "$status" -eq 1 ]
	! git show-ref --verify -q refs/heads/feature/other || false
}
