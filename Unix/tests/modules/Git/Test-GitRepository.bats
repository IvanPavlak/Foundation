#!/usr/bin/env bats
# Test-GitRepository: a .git directory or worktree file, missing paths walked off, outside fails.

load ../../helpers

setup() { setup_foundation; }

@test "Test-GitRepository: .git directory or worktree file, missing paths, outside" {
	mkdir -p "$BATS_TEST_TMPDIR/clone/.git" "$BATS_TEST_TMPDIR/clone/src" "$BATS_TEST_TMPDIR/worktree/sub" "$BATS_TEST_TMPDIR/none"
	echo 'gitdir: /elsewhere' >"$BATS_TEST_TMPDIR/worktree/.git"
	cmd=$UNIX_DIR/modules/Git/bin/Test-GitRepository
	run "${BASH:-bash}" "$cmd" "$BATS_TEST_TMPDIR/clone/src/missing/file.cs"
	[ "$status" -eq 0 ]
	[ "$output" = "$(cd "$BATS_TEST_TMPDIR/clone" && pwd -P)" ]
	run "${BASH:-bash}" "$cmd" "$BATS_TEST_TMPDIR/worktree/sub" --quiet
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	run "${BASH:-bash}" "$cmd" "$BATS_TEST_TMPDIR/none"
	[ "$status" -eq 1 ]
}
