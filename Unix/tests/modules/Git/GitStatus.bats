#!/usr/bin/env bats
# GitStatus (gs): git status with the status-arguments of git.conf (default --short); arguments on
# the call replace the configured ones, as the Windows GitStatusArguments.

# bats file_tags=integration
load ../../helpers
load ../../git

setup() {
	setup_foundation
	git_sandbox
	use_empty_config
	cd "$REPO"
	echo new >untracked.txt
	echo staged >>file.txt
	git add file.txt
	echo unstaged >>file.txt
}

gs() { run "${BASH:-bash}" "$bin/GitStatus" "$@"; }

@test "without a status-arguments line it runs git status --short" {
	gs
	[ "$status" -eq 0 ]
	[[ $output == *"MM file.txt"* ]]
	[[ $output == *"?? untracked.txt"* ]]
	[[ $output != *"Changes to be committed"* ]]
}

@test "the configured status-arguments are used, per machine type" {
	printf 'status-arguments --short\n@Work status-arguments -v -v -u\n' >"$FOUNDATION_CONFIG_DIR/git.conf"
	MACHINE_TYPE=Laptop gs
	[[ $output == *"MM file.txt"* ]]
	MACHINE_TYPE=Work gs
	[ "$status" -eq 0 ]
	[[ $output == *"+staged"* ]]
	[[ $output == *"+unstaged"* ]]
	[[ $output == *untracked.txt* ]]
}

@test "a bare status-arguments line runs a plain git status" {
	printf 'status-arguments\n' >"$FOUNDATION_CONFIG_DIR/git.conf"
	gs
	[ "$status" -eq 0 ]
	[[ $output == *"Changes to be committed"* ]]
	[[ $output != *"+staged"* ]]
}

@test "arguments on the call replace the configured ones entirely" {
	printf 'status-arguments --short\n' >"$FOUNDATION_CONFIG_DIR/git.conf"
	gs -v -v -u
	[ "$status" -eq 0 ]
	[[ $output == *"+staged"* ]]
	[[ $output == *"+unstaged"* ]]
	[[ $output != *"MM file.txt"* ]]
}
