#!/usr/bin/env bats
# GitBranchDeleteAndPrune (gbd): deletes local branches (-d, offering -D for the refused ones) and
# prunes stale origin refs.

# bats file_tags=integration
load ../../helpers
load ../../git

setup() {
	setup_foundation
	git_sandbox
	cd "$REPO"
}

# A local branch with a commit master does not have.
unmerged_branch() {
	git switch -qc "$1"
	echo "$1" >>file.txt
	git commit -qam "Unmerged work on $1"
	git switch -q master
}

@test "deletes a merged local branch with -d and prunes a branch deleted on origin" {
	git branch doomed
	git push -q origin doomed 2>/dev/null
	git push -q origin --delete doomed 2>/dev/null
	git update-ref refs/remotes/origin/doomed "$(git rev-parse doomed)"
	run "${BASH:-bash}" "$bin/GitBranchDeleteAndPrune" doomed
	[ "$status" -eq 0 ]
	! git show-ref --verify -q refs/heads/doomed || false
	! git show-ref --verify -q refs/remotes/origin/doomed || false
}

@test "an unmerged branch is refused, offered for -D, and kept without a terminal" {
	unmerged_branch doomed
	run "${BASH:-bash}" "$bin/GitBranchDeleteAndPrune" doomed
	[ "$status" -eq 1 ]
	[[ $output == *"Not deleted: doomed"* ]]
	git show-ref --verify -q refs/heads/doomed
}

@test "Yes to the offer force-deletes only the refused branches and prunes" {
	git branch merged
	unmerged_branch doomed
	git update-ref refs/remotes/origin/stale "$(git rev-parse master)"
	printf 'Yes\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$bin/GitBranchDeleteAndPrune" merged, doomed
	[ "$status" -eq 0 ]
	[[ $output == *"Force-delete doomed"* ]]
	[[ $output != *"Force-delete merged"* ]]
	! git show-ref --verify -q refs/heads/merged || false
	! git show-ref --verify -q refs/heads/doomed || false
	! git show-ref --verify -q refs/remotes/origin/stale || false
}

@test "Enter at the offer keeps the refused branch and fails" {
	git branch merged
	unmerged_branch doomed
	printf '\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$bin/GitBranchDeleteAndPrune" merged doomed
	[ "$status" -eq 1 ]
	! git show-ref --verify -q refs/heads/merged || false
	git show-ref --verify -q refs/heads/doomed
}

@test "--force deletes an unmerged branch with -D and asks nothing" {
	unmerged_branch doomed
	printf 'No\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$bin/GitBranchDeleteAndPrune" doomed --force
	[ "$status" -eq 0 ]
	[[ $output != *"Force-delete"* ]]
	! git show-ref --verify -q refs/heads/doomed || false
}

@test "without a name and without a terminal it fails and deletes nothing" {
	git branch doomed
	run "${BASH:-bash}" "$bin/GitBranchDeleteAndPrune"
	[ "$status" -ne 0 ]
	git show-ref --verify -q refs/heads/master
	git show-ref --verify -q refs/heads/doomed
}

@test "without a name the menu lists every branch but the checked-out one and deletes the ones picked" {
	git branch alpha
	git branch beta
	git branch gamma
	printf '1, gamma\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$bin/GitBranchDeleteAndPrune"
	[ "$status" -eq 0 ]
	[[ $output == *"[Local Branches]"* ]]
	[[ $output == *"alpha"* ]]
	[[ $output != *"] master"* ]]
	! git show-ref --verify -q refs/heads/alpha || false
	git show-ref --verify -q refs/heads/beta
	! git show-ref --verify -q refs/heads/gamma || false
	git show-ref --verify -q refs/heads/master
}

@test "without a name an empty answer deletes nothing and succeeds" {
	git branch keep
	printf '\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$bin/GitBranchDeleteAndPrune"
	[ "$status" -eq 0 ]
	git show-ref --verify -q refs/heads/keep
}

@test "without a name and no branch besides the checked-out one it asks nothing" {
	run "${BASH:-bash}" "$bin/GitBranchDeleteAndPrune"
	[ "$status" -eq 0 ]
	[[ $output == *"No local branch to delete"* ]]
	git show-ref --verify -q refs/heads/master
}

@test "the Windows -BranchName and -Force name the branches; -WhatIf deletes nothing" {
	git branch doomed
	unmerged_branch other
	run "${BASH:-bash}" "$bin/GitBranchDeleteAndPrune" doomed -WhatIf
	[ "$status" -eq 1 ]
	git show-ref --verify -q refs/heads/doomed
	run "${BASH:-bash}" "$bin/GitBranchDeleteAndPrune" -BranchName doomed, other -Force
	[ "$status" -eq 0 ]
	! git show-ref --verify -q refs/heads/doomed || false
	! git show-ref --verify -q refs/heads/other || false
}
