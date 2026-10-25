#!/usr/bin/env bats
# Merge-Upstream against throwaway repositories (real git, user config never read): the fork is the
# sandbox clone, the upstream a bare repository that shares its first commit, and upstream.conf owns
# Unix/ and docs/unix/. The merge is always left staged, never committed.

# bats file_tags=integration
load ../../helpers
load ../../git

setup() {
	setup_foundation
	git_sandbox
	# The fork's tree before the upstream diverges: an owned file, a shared file and a mirrored one.
	mkdir -p "$REPO/Unix" "$REPO/docs/unix"
	echo engine >"$REPO/Unix/engine.sh"
	echo readme >"$REPO/README.md"
	echo license >"$REPO/LICENSE"
	git -C "$REPO" add -A
	git -C "$REPO" commit -qm "Shared start"
	UPSTREAM=$BATS_TEST_TMPDIR/upstream.git
	UPWORK=$BATS_TEST_TMPDIR/upwork
	git clone -q --bare "$REPO" "$UPSTREAM"
	git clone -q "$UPSTREAM" "$UPWORK" 2>/dev/null
	git -C "$REPO" remote add foundation "$UPSTREAM"
	export DOTFILES_ROOT=$REPO
	use_empty_config
	conf ""
}

# upstream.conf: the own and mirror lines, then the lines given.
conf() {
	{
		printf 'own Unix/\nown docs/unix/\nmirror LICENSE\n'
		printf '%s\n' "$@"
	} >"$FOUNDATION_CONFIG_DIR/upstream.conf"
}
# Write FILE with CONTENT in the upstream (empty CONTENT deletes it), commit and push.
upstream() {
	if [ -z "$2" ]; then
		git -C "$UPWORK" rm -q -- "$1"
	else
		mkdir -p "$(dirname "$UPWORK/$1")"
		printf '%s\n' "$2" >"$UPWORK/$1"
		git -C "$UPWORK" add -- "$1"
	fi
	git -C "$UPWORK" commit -qm "Upstream $1"
	git -C "$UPWORK" push -q origin master 2>/dev/null
}
merge() { run "${BASH:-bash}" "$bin/Merge-Upstream" "$@"; }
staged() { git -C "$REPO" diff --cached --name-only HEAD | LC_ALL=C sort | tr '\n' ' '; }
merging() { git -C "$REPO" rev-parse -q --verify MERGE_HEAD >/dev/null; }

@test "--owned-only takes the owned paths and puts every other path back, committing nothing" {
	upstream Unix/engine.sh "engine v2"
	upstream docs/unix/page.md "new page"
	upstream README.md "their readme"
	upstream Root.md "their root file"
	upstream file.txt ""
	head=$(git -C "$REPO" rev-parse HEAD)
	merge foundation --owned-only
	[ "$status" -eq 0 ]
	merging
	[ "$(staged)" = "Unix/engine.sh docs/unix/page.md " ]
	[ "$(cat "$REPO/Unix/engine.sh")" = "engine v2" ]
	[ "$(cat "$REPO/README.md")" = readme ]
	[ ! -e "$REPO/Root.md" ]
	[ "$(cat "$REPO/file.txt")" = one ]
	[ "$(git -C "$REPO" rev-parse HEAD)" = "$head" ]
	[[ $output == *README.md* ]]
	[[ $output == *Root.md* ]]
}

@test "without --owned-only every upstream change is staged" {
	upstream Unix/engine.sh "engine v2"
	upstream README.md "their readme"
	merge foundation
	[ "$status" -eq 0 ]
	merging
	[ "$(staged)" = "README.md Unix/engine.sh " ]
}

@test "an owned-only line naming the remote makes --owned-only the default; --all-paths overrides it" {
	conf "owned-only other foundation"
	upstream Unix/engine.sh "engine v2"
	upstream README.md "their readme"
	merge foundation
	[ "$status" -eq 0 ]
	[ "$(staged)" = "Unix/engine.sh " ]
	git -C "$REPO" merge --abort
	merge foundation --all-paths
	[ "$status" -eq 0 ]
	[ "$(staged)" = "README.md Unix/engine.sh " ]
}

@test "an owned-only line for another remote leaves this one merging every path" {
	conf "owned-only other"
	upstream README.md "their readme"
	merge foundation
	[ "$status" -eq 0 ]
	[ "$(staged)" = "README.md " ]
}

@test "a mirrored file the upstream changed is taken back and named as mirrored" {
	upstream LICENSE "their license"
	upstream Unix/engine.sh "engine v2"
	merge foundation --owned-only
	[ "$status" -eq 0 ]
	[ "$(cat "$REPO/LICENSE")" = license ]
	[[ $output == *"LICENSE - a mirrored file"* ]]
}

@test "a conflict outside the owned paths is taken back; one inside is left to resolve" {
	echo "our readme" >"$REPO/README.md"
	echo "our engine" >"$REPO/Unix/engine.sh"
	git -C "$REPO" commit -qam "Fork edits"
	upstream README.md "their readme"
	upstream Unix/engine.sh "their engine"
	merge foundation --owned-only
	[ "$status" -eq 1 ]
	merging
	[ "$(git -C "$REPO" diff --name-only --diff-filter=U)" = Unix/engine.sh ]
	[ "$(cat "$REPO/README.md")" = "our readme" ]
	[[ $output == *Unix/engine.sh* ]]
}

@test "--dry-run lists what would be taken back and merges nothing" {
	upstream Unix/engine.sh "engine v2"
	upstream README.md "their readme"
	merge foundation --dry-run --owned-only
	[ "$status" -eq 0 ]
	! merging || false
	[ -z "$(staged)" ]
	[ "$(cat "$REPO/Unix/engine.sh")" = engine ]
	[[ $output == *"Would take 1 of the 2"* ]]
	[[ $output == *README.md* ]]
}

@test "the Windows -WhatIf is the dry run and -OwnedOnly the flag" {
	upstream README.md "their readme"
	merge foundation -OwnedOnly -WhatIf
	[ "$status" -eq 0 ]
	! merging || false
	[[ $output == *"Would take 0 of the 1"* ]]
}

@test "uncommitted changes to tracked files stop it before anything is fetched or merged" {
	upstream Unix/engine.sh "engine v2"
	echo "work in progress" >>"$REPO/README.md"
	merge foundation
	[ "$status" -eq 1 ]
	! merging || false
	[ "$(tail -n1 "$REPO/README.md")" = "work in progress" ]
	! git -C "$REPO" show-ref --verify -q refs/remotes/foundation/master || false
}

@test "a merge already in progress stops it" {
	upstream Unix/engine.sh "engine v2"
	merge foundation
	merging
	merge foundation
	[ "$status" -eq 1 ]
	[[ $output == *"already in progress"* ]]
}

@test "nothing new upstream is a success with nothing in progress" {
	merge foundation
	[ "$status" -eq 0 ]
	! merging || false
	[[ $output == *"Already up to date"* ]]
}

@test "an unknown remote, a missing branch and two remotes are refused" {
	merge nosuchremote
	[ "$status" -eq 1 ]
	[[ $output == *"No remote named [nosuchremote]"* ]]
	merge foundation --branch nosuchbranch
	[ "$status" -eq 1 ]
	merge foundation other
	[ "$status" -eq 1 ]
	merge
	[ "$status" -eq 1 ]
}

@test "an upstream with no shared history is refused with the bridge to run" {
	alone=$BATS_TEST_TMPDIR/alone
	git init -q "$alone"
	echo other >"$alone/other.txt"
	git -C "$alone" add other.txt
	git -C "$alone" commit -qm "Unrelated"
	git -C "$REPO" remote add alone "$alone"
	merge alone
	[ "$status" -eq 1 ]
	[[ $output == *"allow-unrelated-histories"* ]]
	! merging || false
}

@test "--owned-only without own lines fails before merging" {
	printf 'mirror LICENSE\n' >"$FOUNDATION_CONFIG_DIR/upstream.conf"
	upstream Unix/engine.sh "engine v2"
	merge foundation --owned-only
	[ "$status" -eq 1 ]
	! merging || false
}
