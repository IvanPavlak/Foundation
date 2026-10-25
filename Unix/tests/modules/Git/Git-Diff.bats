#!/usr/bin/env bats
# Git-Diff (gdf): every change against HEAD, staged or not.

# bats file_tags=integration
load ../../helpers
load ../../git

setup() {
	setup_foundation
	git_sandbox
	cd "$REPO"
}

@test "shows staged and unstaged changes together, nothing when clean" {
	run "${BASH:-bash}" "$bin/Git-Diff"
	[ "$status" -eq 0 ]
	[[ $output != *"+one"* ]]
	echo staged >>file.txt
	git add file.txt
	echo unstaged >>file.txt
	run "${BASH:-bash}" "$bin/Git-Diff"
	[[ $output == *"+staged"* ]]
	[[ $output == *"+unstaged"* ]]
}
