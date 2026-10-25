#!/usr/bin/env bats
# GitPull (gp): git pull with every argument passed through.

# bats file_tags=integration
load ../../helpers
load ../../git

setup() {
	setup_foundation
	git_sandbox
}

@test "pulls a commit another clone pushed" {
	git clone -q "$ORIGIN" "$BATS_TEST_TMPDIR/other" 2>/dev/null
	echo pushed >"$BATS_TEST_TMPDIR/other/pushed.txt"
	git -C "$BATS_TEST_TMPDIR/other" add pushed.txt
	git -C "$BATS_TEST_TMPDIR/other" commit -qm "Pushed elsewhere"
	git -C "$BATS_TEST_TMPDIR/other" push -q origin master 2>/dev/null
	cd "$REPO"
	run "${BASH:-bash}" "$bin/GitPull" --ff-only
	[ "$status" -eq 0 ]
	[ -f pushed.txt ]
}
