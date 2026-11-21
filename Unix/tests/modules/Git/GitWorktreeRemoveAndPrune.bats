#!/usr/bin/env bats
# GitWorktreeRemoveAndPrune (gwd): prunes stale worktree entries, removes linked worktrees and
# offers to delete their branches through GitBranchDeleteAndPrune.

# bats file_tags=integration
load ../../helpers
load ../../git

setup() {
	setup_foundation
	git_sandbox
	cd "$REPO"
	WT=$BATS_TEST_TMPDIR/wt
	mkdir -p "$WT"
}

# A linked worktree at $WT/NAME on a new branch BRANCH.
add_worktree() {
	git worktree add -q -b "$2" "$WT/$1" 2>/dev/null
}

has_worktree() {
	git worktree list --porcelain | grep -q "^worktree .*/wt/$1\$"
}

@test "prunes a worktree whose folder was deleted before offering the others" {
	add_worktree gone feature/gone
	add_worktree kept feature/kept
	rm -rf "$WT/gone"
	printf '\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$bin/GitWorktreeRemoveAndPrune"
	[ "$status" -eq 0 ]
	[[ $output == *"feature/kept"* ]]
	[[ $output != *"feature/gone"* ]]
	! has_worktree gone || false
	has_worktree kept
}

@test "the menu leaves out the main and locked worktrees, and Enter removes nothing" {
	add_worktree a feature/a
	add_worktree locked feature/locked
	git worktree lock "$WT/locked"
	printf '\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$bin/GitWorktreeRemoveAndPrune"
	[ "$status" -eq 0 ]
	[[ $output == *"[Worktrees]"* ]]
	[[ $output == *"[1] feature/a"* ]]
	[[ $output != *"] master"* ]]
	[[ $output != *"[2]"* ]]
	[[ $output == *"[locked] feature/locked"* ]]
	has_worktree a
	has_worktree locked
}

@test "the menu removes the worktree picked, and the same answer 1 is Yes for its branch" {
	add_worktree a feature/a
	add_worktree b feature/b
	# Every prompt reads the first line of the answers file: 1 picks the first worktree, then Yes.
	printf '1\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$bin/GitWorktreeRemoveAndPrune"
	[ "$status" -eq 0 ]
	! has_worktree a || false
	has_worktree b
	! git show-ref --verify -q refs/heads/feature/a || false
	git show-ref --verify -q refs/heads/feature/b
}

@test "without a linked worktree it says so and asks nothing" {
	run "${BASH:-bash}" "$bin/GitWorktreeRemoveAndPrune"
	[ "$status" -eq 0 ]
	[[ $output == *"No worktree to remove"* ]]
}

@test "names a worktree by its branch or a relative path, and Enter keeps the branches" {
	add_worktree a feature/a
	add_worktree b feature/b
	printf '\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$bin/GitWorktreeRemoveAndPrune" feature/a, ../wt/b
	[ "$status" -eq 0 ]
	[[ $output == *"[Branches]"* ]]
	! has_worktree a || false
	! has_worktree b || false
	git show-ref --verify -q refs/heads/feature/a
	git show-ref --verify -q refs/heads/feature/b
}

@test "a worktree with changes is refused without --force and removed with it" {
	add_worktree dirty feature/dirty
	echo change >"$WT/dirty/untracked.txt"
	run "${BASH:-bash}" "$bin/GitWorktreeRemoveAndPrune" feature/dirty
	[ "$status" -eq 1 ]
	has_worktree dirty
	run "${BASH:-bash}" "$bin/GitWorktreeRemoveAndPrune" feature/dirty --force
	[ "$status" -eq 0 ]
	! has_worktree dirty || false
	# No terminal answers the branch question No, whatever --force did to the worktree.
	git show-ref --verify -q refs/heads/feature/dirty
}

@test "the main, current, locked and unknown worktrees are refused and the rest still go" {
	add_worktree a feature/a
	add_worktree here feature/here
	add_worktree locked feature/locked
	git worktree lock "$WT/locked"
	cd "$WT/here"
	run "${BASH:-bash}" "$bin/GitWorktreeRemoveAndPrune" master feature/here feature/locked feature/nope feature/a
	[ "$status" -eq 1 ]
	[[ $output == *"[master] is the main worktree"* ]]
	[[ $output == *"[feature/here] is the worktree you are in"* ]]
	[[ $output == *"[feature/locked] is locked"* ]]
	[[ $output == *"No worktree has [feature/nope]"* ]]
	! has_worktree a || false
	has_worktree here
	has_worktree locked
}

@test "Force deletes an unmerged branch of a removed worktree with -D" {
	add_worktree a feature/a
	git -C "$WT/a" commit -q --allow-empty -m "Unmerged work"
	printf 'Force\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$bin/GitWorktreeRemoveAndPrune" feature/a
	[ "$status" -eq 0 ]
	! has_worktree a || false
	! git show-ref --verify -q refs/heads/feature/a || false
}

@test "Yes hands an unmerged branch to gbd, which offers -D for it" {
	add_worktree a feature/a
	git -C "$WT/a" commit -q --allow-empty -m "Unmerged work"
	# Yes answers this command's question and then gbd's force offer.
	printf 'Yes\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$bin/GitWorktreeRemoveAndPrune" feature/a
	[ "$status" -eq 0 ]
	[[ $output == *"Force-delete feature/a"* ]]
	! git show-ref --verify -q refs/heads/feature/a || false
}

@test "a detached worktree is removed without a branch question" {
	git worktree add -q --detach "$WT/detached" 2>/dev/null
	printf 'Yes\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$bin/GitWorktreeRemoveAndPrune" "$WT/detached"
	[ "$status" -eq 0 ]
	[[ $output != *"[Branches]"* ]]
	! has_worktree detached || false
}

@test "the Windows -Worktree and -Force name the worktrees; -WhatIf removes nothing" {
	add_worktree a feature/a
	echo change >"$WT/a/untracked.txt"
	run "${BASH:-bash}" "$bin/GitWorktreeRemoveAndPrune" feature/a -WhatIf
	[ "$status" -eq 1 ]
	has_worktree a
	run "${BASH:-bash}" "$bin/GitWorktreeRemoveAndPrune" -Worktree feature/a -Force
	[ "$status" -eq 0 ]
	! has_worktree a || false
}
