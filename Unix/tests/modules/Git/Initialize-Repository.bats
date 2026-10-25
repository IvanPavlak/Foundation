#!/usr/bin/env bats
# Initialize-Repository: clones URL into DIR, pulls when DIR already is a checkout, --archive leaves
# a plain folder without history, -Token is taken and not used, and an unknown argument clones nothing.

# bats file_tags=integration
load ../../helpers
load ../../git

setup() {
	setup_foundation
	git_sandbox
}

@test "clones into a new folder, then pulls on the second run" {
	target=$BATS_TEST_TMPDIR/cloned
	run "${BASH:-bash}" "$bin/Initialize-Repository" "$ORIGIN" "$target"
	[ "$status" -eq 0 ]
	[ -f "$target/file.txt" ]
	[ -d "$target/.git" ]
	echo later >"$REPO/later.txt"
	git -C "$REPO" add later.txt
	git -C "$REPO" commit -qm "Later"
	git -C "$REPO" push -q origin master 2>/dev/null
	run "${BASH:-bash}" "$bin/Initialize-Repository" "$ORIGIN" "$target"
	[ "$status" -eq 0 ]
	[ -f "$target/later.txt" ]
}

@test "--archive leaves the files without .git" {
	target=$BATS_TEST_TMPDIR/archived
	run "${BASH:-bash}" "$bin/Initialize-Repository" "file://$ORIGIN" "$target" --archive
	[ "$status" -eq 0 ]
	[ -f "$target/file.txt" ]
	[ ! -e "$target/.git" ]
}

@test "the Windows call shape: -Token is taken with its value and warned about, the clone lands in -LocalPath" {
	mkdir -p "$BATS_TEST_TMPDIR/work"
	cd "$BATS_TEST_TMPDIR/work"
	target=$BATS_TEST_TMPDIR/cloned
	run "${BASH:-bash}" "$bin/Initialize-Repository" -RepositoryUrl "$ORIGIN" -LocalPath "$target" -Token SecretToken
	[ "$status" -eq 0 ]
	[ -f "$target/file.txt" ]
	[[ $output == *"--token is not used"* ]]
	[ ! -e "$BATS_TEST_TMPDIR/work/SecretToken" ]
	[ -z "$(ls -A "$BATS_TEST_TMPDIR/work")" ]
}

@test "an unknown flag or a third path fails before anything is cloned" {
	mkdir -p "$BATS_TEST_TMPDIR/work"
	cd "$BATS_TEST_TMPDIR/work"
	run "${BASH:-bash}" "$bin/Initialize-Repository" "$ORIGIN" "$BATS_TEST_TMPDIR/one" --bogus-flag
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$bin/Initialize-Repository" "$ORIGIN" "$BATS_TEST_TMPDIR/one" extra
	[ "$status" -ne 0 ]
	[ ! -e "$BATS_TEST_TMPDIR/one" ]
	[ -z "$(ls -A "$BATS_TEST_TMPDIR/work")" ]
}

# Commit FILE on master in the sandbox clone and push it to origin. Usage: push_upstream FILE
push_upstream() {
	echo "$1" >"$REPO/$1"
	git -C "$REPO" add "$1"
	git -C "$REPO" commit -qm "Upstream $1"
	git -C "$REPO" push -q origin master 2>/dev/null
}

@test "S36: a second run on a dirty checkout updates it and keeps staged, modified and untracked work" {
	target=$BATS_TEST_TMPDIR/cloned
	run "${BASH:-bash}" "$bin/Initialize-Repository" "$ORIGIN" "$target"
	[ "$status" -eq 0 ]
	echo staged >"$target/staged.txt"
	git -C "$target" add staged.txt
	echo changed >"$target/file.txt"
	echo untracked >"$target/untracked.txt"
	push_upstream later.txt
	run "${BASH:-bash}" "$bin/Initialize-Repository" "$ORIGIN" "$target"
	[ "$status" -eq 0 ]
	[ -f "$target/later.txt" ]
	git -C "$target" diff --cached --name-only | grep -qx staged.txt
	[ "$(cat "$target/file.txt")" = changed ]
	[ "$(cat "$target/untracked.txt")" = untracked ]
	[ -z "$(git -C "$target" stash list)" ]
}

@test "a URL repositories.conf marks shallow is cloned --depth 1 with its .git; any other URL in full" {
	push_upstream second.txt
	export FOUNDATION_CONFIG_DIR=$BATS_TEST_TMPDIR/config
	mkdir -p "$FOUNDATION_CONFIG_DIR"
	notes=$(origin_url Notes)
	printf '[Demo]\nNotes  %s.git/  $DEV/Notes  shallow\nOther  %s  $DEV/Other\n' "${notes%.git}" "$(origin_url Other)" >"$FOUNDATION_CONFIG_DIR/repositories.conf"
	run "${BASH:-bash}" "$bin/Initialize-Repository" "$notes" "$BATS_TEST_TMPDIR/notes"
	[ "$status" -eq 0 ]
	[ "$(git -C "$BATS_TEST_TMPDIR/notes" rev-parse --is-shallow-repository)" = true ]
	[ "$(git -C "$BATS_TEST_TMPDIR/notes" rev-list --count HEAD)" -eq 1 ]
	run "${BASH:-bash}" "$bin/Initialize-Repository" "$(origin_url Other)" "$BATS_TEST_TMPDIR/other"
	[ "$status" -eq 0 ]
	[ "$(git -C "$BATS_TEST_TMPDIR/other" rev-parse --is-shallow-repository)" = false ]
	[ "$(git -C "$BATS_TEST_TMPDIR/other" rev-list --count HEAD)" -eq 2 ]
}
