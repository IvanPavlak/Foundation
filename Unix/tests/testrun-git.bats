#!/usr/bin/env bats
# lib/testrun.sh against a real throwaway repository: the changed paths since a base (committed,
# uncommitted, untracked, deleted) and the working-tree fingerprint the gate stamp compares.

# bats file_tags=integration
load helpers
load git

setup() {
	setup_foundation
	git_sandbox
	foundation_load testrun
	cd "$REPO" || return 1
}

@test "changed paths: commits since the merge base, uncommitted edits, deletions and untracked files" {
	echo keep >gone.txt
	git add gone.txt
	git commit -qm "Add gone"
	git switch -qc work
	echo two >committed.txt
	git add committed.txt
	git commit -qm "Work"
	echo edit >>file.txt
	git rm -q gone.txt
	echo new >untracked.txt
	run testrun_changed_paths master
	[ "$status" -eq 0 ]
	[ "$(LC_ALL=C sort <<<"$output")" = "$(printf 'A\tcommitted.txt\nA\tuntracked.txt\nD\tgone.txt\nM\tfile.txt')" ]
}

@test "changed paths: nothing changed is empty, an unknown base fails" {
	run testrun_changed_paths master
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	run testrun_changed_paths no-such-branch
	[ "$status" -ne 0 ]
}

@test "the fingerprint changes with an edit or an untracked file and returns with the tree" {
	first=$(testrun_fingerprint)
	[ "$(testrun_fingerprint)" = "$first" ]
	echo edit >>file.txt
	[ "$(testrun_fingerprint)" != "$first" ]
	git checkout -q -- file.txt
	[ "$(testrun_fingerprint)" = "$first" ]
	echo new >untracked.txt
	[ "$(testrun_fingerprint)" != "$first" ]
}
