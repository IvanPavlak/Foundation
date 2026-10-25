#!/usr/bin/env bats
# git-obsidian against a throwaway vault (the sandbox clone) and its bare origin: pending changes
# are committed as a Vault Backup and pushed, a commit an earlier run could not push is pushed on
# a clean tree, a failed push or a branch without upstream is an error that keeps the commit, and a
# clean, pushed vault is left alone - the Git-Obsidian cases of Windows.

# bats file_tags=integration
load ../../helpers
load ../../git

setup() {
	setup_foundation
	git_sandbox
	# The vault tracks origin's master, as a real clone of the vault does.
	git -C "$REPO" branch -q --set-upstream-to=origin/master master
	export OBSIDIAN_DIRECTORY=$REPO
	obsidian=$bin/git-obsidian
}

# The number of commits origin's master lacks from the vault's.
unpushed() { git -C "$REPO" rev-list --count origin/master..master; }

@test "a dirty vault is committed as a Vault Backup and pushed" {
	echo note >"$REPO/note.md"
	echo changed >"$REPO/file.txt"
	run sh "$obsidian"
	[ "$status" -eq 0 ]
	[[ $output == *"Obsidian updated!"* ]]
	[[ "$(git -C "$REPO" log -1 --format=%s)" == "Vault Backup: "* ]]
	[ -z "$(git -C "$REPO" status --porcelain)" ]
	[ "$(git -C "$ORIGIN" rev-parse master)" = "$(git -C "$REPO" rev-parse HEAD)" ]
	git -C "$ORIGIN" show master:note.md | grep -qx note
}

@test "a clean vault with a commit an earlier run could not push pushes it" {
	echo note >"$REPO/note.md"
	git -C "$REPO" add note.md
	git -C "$REPO" commit -qm "Earlier backup"
	run sh "$obsidian"
	[ "$status" -eq 0 ]
	[[ $output == *"Found [1] unpushed commit(s) from an earlier run"* ]]
	[ "$(git -C "$ORIGIN" rev-parse master)" = "$(git -C "$REPO" rev-parse HEAD)" ]
}

@test "a push to an unreachable origin exits 1 and keeps the commit" {
	mv "$ORIGIN" "$ORIGIN.gone"
	echo note >"$REPO/note.md"
	run sh "$obsidian"
	[ "$status" -eq 1 ]
	[[ $output == *"Push failed - the vault is committed locally"* ]]
	[[ "$(git -C "$REPO" log -1 --format=%s)" == "Vault Backup: "* ]]
	[ -z "$(git -C "$REPO" status --porcelain)" ]
	mv "$ORIGIN.gone" "$ORIGIN"
	[ "$(unpushed)" -eq 1 ]
}

@test "a vault branch without upstream exits 1 with git's own error, the commit kept" {
	git -C "$REPO" checkout -q -b no-upstream
	echo note >"$REPO/note.md"
	run sh "$obsidian"
	[ "$status" -eq 1 ]
	[[ $output == *"Push failed"* ]]
	[[ "$(git -C "$REPO" log -1 --format=%s)" == "Vault Backup: "* ]]
	! git -C "$ORIGIN" show-ref --verify --quiet refs/heads/no-upstream || false
}

@test "a clean, pushed vault does nothing" {
	before=$(git -C "$REPO" rev-parse HEAD)
	run sh "$obsidian"
	[ "$status" -eq 0 ]
	[[ $output == *"No changes to update!"* ]]
	[ "$(git -C "$REPO" rev-parse HEAD)" = "$before" ]
	[ "$(git -C "$REPO" rev-list --count HEAD)" -eq 1 ]
}
