#!/usr/bin/env bats
# GitBranchDeleteAndPrune (gbd): force-deletes a local branch and prunes stale origin refs.

# bats file_tags=integration
load ../../helpers
load ../../git

setup() {
	setup_foundation
	git_sandbox
	cd "$REPO"
}

@test "deletes an unmerged local branch and prunes a branch deleted on origin" {
	git switch -qc doomed
	echo two >>file.txt
	git commit -qam "Unmerged work"
	git push -q origin doomed 2>/dev/null
	git switch -q master
	git push -q origin --delete doomed 2>/dev/null
	git update-ref refs/remotes/origin/doomed "$(git rev-parse doomed)"
	run "${BASH:-bash}" "$bin/GitBranchDeleteAndPrune" doomed
	[ "$status" -eq 0 ]
	! git show-ref --verify -q refs/heads/doomed || false
	! git show-ref --verify -q refs/remotes/origin/doomed || false
}

@test "without a name it fails and deletes nothing" {
	run "${BASH:-bash}" "$bin/GitBranchDeleteAndPrune"
	[ "$status" -ne 0 ]
	git show-ref --verify -q refs/heads/master
}

@test "the Windows -BranchName names the branch; -WhatIf deletes nothing" {
	git branch doomed
	run "${BASH:-bash}" "$bin/GitBranchDeleteAndPrune" doomed -WhatIf
	[ "$status" -eq 1 ]
	git show-ref --verify -q refs/heads/doomed
	run "${BASH:-bash}" "$bin/GitBranchDeleteAndPrune" -BranchName doomed
	[ "$status" -eq 0 ]
	! git show-ref --verify -q refs/heads/doomed || false
}
