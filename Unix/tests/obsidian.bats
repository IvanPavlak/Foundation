#!/usr/bin/env bats
# The Obsidian vault folder: OBSIDIAN_DIRECTORY, else the directory line of obsidian.conf, else
# nothing - and git-obsidian stops before touching any repository when no vault is found, or when
# it is asked for help.

load helpers

setup() {
	setup_foundation
	foundation_load obsidian
	use_empty_config
	unset OBSIDIAN_DIRECTORY
}

@test "the directory line of obsidian.conf names the vault, ~ expands, the folder names the vault" {
	printf '%s\n' 'directory ~/Notes/MyVault' >"$FOUNDATION_CONFIG_DIR/obsidian.conf"
	run obsidian_directory
	[ "$output" = "$HOME/Notes/MyVault" ]
	run obsidian_vault
	[ "$output" = MyVault ]
}

@test "OBSIDIAN_DIRECTORY wins over obsidian.conf, and a vault line over the folder name" {
	printf '%s\n' 'directory ~/Notes/MyVault' 'vault Named' >"$FOUNDATION_CONFIG_DIR/obsidian.conf"
	OBSIDIAN_DIRECTORY=/elsewhere/Other run obsidian_directory
	[ "$output" = /elsewhere/Other ]
	run obsidian_vault
	[ "$output" = Named ]
}

@test "without a vault folder the directory fails, the vault name is empty and no workspace is listed" {
	run obsidian_directory
	[ "$status" -ne 0 ]
	[ -z "$output" ]
	run obsidian_vault
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	run obsidian_workspace_names
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "git-obsidian stops when no vault is configured or the vault folder is missing" {
	run sh "$UNIX_DIR/modules/Git/bin/git-obsidian"
	[ "$status" -eq 1 ]
	[[ $output == *"No Obsidian vault configured"* ]]
	printf '%s\n' "directory $BATS_TEST_TMPDIR/missing-vault" >"$FOUNDATION_CONFIG_DIR/obsidian.conf"
	run sh "$UNIX_DIR/modules/Git/bin/git-obsidian"
	[ "$status" -eq 1 ]
	[[ $output == *"Obsidian vault not found: $BATS_TEST_TMPDIR/missing-vault"* ]]
}

@test "git-obsidian --help prints its usage and runs no git command; an unknown argument fails" {
	stub_tool git
	[ "$(command -v git)" = "$BATS_TEST_TMPDIR/tools/git" ]
	mkdir -p "$BATS_TEST_TMPDIR/vault"
	export OBSIDIAN_DIRECTORY=$BATS_TEST_TMPDIR/vault
	for flag in --help -h; do
		run sh "$UNIX_DIR/modules/Git/bin/git-obsidian" "$flag"
		[ "$status" -eq 0 ]
		[[ $output == *"Usage: git-obsidian"* ]]
	done
	run sh "$UNIX_DIR/modules/Git/bin/git-obsidian" --bogus-flag
	[ "$status" -eq 1 ]
	[ ! -e "$BATS_TEST_TMPDIR/tool.log" ]
}
