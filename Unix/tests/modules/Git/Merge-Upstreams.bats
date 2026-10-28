#!/usr/bin/env bats
# Merge-Upstreams against throwaway repositories (real git, user config never read): the fork is the
# sandbox clone, the upstream a bare repository that shares its first commits, and the fork's HEAD
# carries Foundation's manifest (Unix/config/upstream.conf: own Unix/ and docs/foundation/, mirror
# LICENSE). Tests that need a second upstream add WinuX's manifest (Windows/PowerShell/Upstream.conf,
# own Windows/). The merge is always left staged, never committed.

# bats file_tags=integration
load ../../helpers
load ../../git

setup() {
	setup_foundation
	git_sandbox
	UPSTREAM=$BATS_TEST_TMPDIR/upstream.git
	UPWORK=$BATS_TEST_TMPDIR/upwork
	# The shared start: Foundation's manifest and changelog, an owned file, a hallway file and a
	# mirrored one.
	mkdir -p "$REPO/Unix/config" "$REPO/docs/foundation"
	manifest >"$REPO/Unix/config/upstream.conf"
	printf '# Changelog\n\n## [Unreleased]\n' >"$REPO/Unix/CHANGELOG.md"
	echo engine >"$REPO/Unix/engine.sh"
	echo readme >"$REPO/README.md"
	echo license >"$REPO/LICENSE"
	git -C "$REPO" add -A
	git -C "$REPO" commit -qm "Shared start"
	git clone -q --bare "$REPO" "$UPSTREAM"
	git clone -q "$UPSTREAM" "$UPWORK" 2>/dev/null
	git -C "$REPO" remote add foundation "$UPSTREAM"
	export DOTFILES_ROOT=$REPO
}

# Foundation's manifest, plus the lines given.
manifest() {
	printf 'name        foundation\nurl         %s\ntag-prefix  foundation\nchangelog   Unix/CHANGELOG.md\n' "$UPSTREAM"
	printf 'own         Unix/\nown         docs/foundation/\nmirror      LICENSE\n'
	[ $# -eq 0 ] || printf '%s\n' "$@"
}
# A second upstream in the fork's HEAD: WinuX's manifest, owning Windows/.
second_upstream() {
	mkdir -p "$REPO/Windows/PowerShell"
	printf '# WinuX\nname winux\nurl https://example.invalid/WinuX.git\nown Windows/\nmirror LICENSE\n' >"$REPO/Windows/PowerShell/Upstream.conf"
	git -C "$REPO" add -A
	git -C "$REPO" commit -qm "Second upstream"
}
# The fork's settings file, Git/upstreams.local.conf, with the lines given (left untracked).
settings() {
	mkdir -p "$REPO/Git"
	printf '%s\n' "$@" >"$REPO/Git/upstreams.local.conf"
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
merge() { run "${BASH:-bash}" "$bin/Merge-Upstreams" "$@"; }
staged() { git -C "$REPO" diff --cached --name-only HEAD | LC_ALL=C sort | tr '\n' ' '; }
merging() { git -C "$REPO" rev-parse -q --verify MERGE_HEAD >/dev/null; }

@test "with one upstream it owns the root: own and hallway paths are staged, nothing is committed" {
	upstream Unix/engine.sh "engine v2"
	upstream README.md "their readme"
	upstream Root.md "their root file"
	head=$(git -C "$REPO" rev-parse HEAD)
	merge foundation
	[ "$status" -eq 0 ]
	merging
	[ "$(staged)" = "README.md Root.md Unix/engine.sh " ]
	[ "$(cat "$REPO/Unix/engine.sh")" = "engine v2" ]
	[ "$(cat "$REPO/README.md")" = "their readme" ]
	[ "$(git -C "$REPO" rev-parse HEAD)" = "$head" ]
}

@test "with two upstreams the root is the fork's: the hallway is declined, own and mirror paths are taken" {
	second_upstream
	upstream Unix/engine.sh "engine v2"
	upstream docs/foundation/page.md "new page"
	upstream LICENSE "license v2"
	upstream README.md "their readme"
	upstream New/Deep/file.md "their new file"
	upstream file.txt ""
	merge foundation
	[ "$status" -eq 0 ]
	merging
	[ "$(staged)" = "LICENSE Unix/engine.sh docs/foundation/page.md " ]
	[ "$(cat "$REPO/README.md")" = readme ]
	[ "$(cat "$REPO/file.txt")" = one ]
	[ ! -e "$REPO/New" ]
	[[ $output == *README.md* ]]
	[[ $output == *New/Deep/file.md* ]]
	[[ $output == *file.txt* ]]
}

@test "a root-owner line decides the hallway: the merged upstream takes it, fork declines it" {
	second_upstream
	upstream README.md "their readme"
	settings "root-owner foundation"
	merge foundation
	[ "$status" -eq 0 ]
	[ "$(staged)" = "README.md " ]
	git -C "$REPO" merge --abort
	settings "# the fork keeps its root" "root-owner fork"
	git -C "$REPO" rm -q --cached Windows/PowerShell/Upstream.conf
	git -C "$REPO" commit -qm "One upstream again"
	merge foundation
	[ "$status" -eq 0 ]
	merging
	[ -z "$(staged)" ]
	[ "$(cat "$REPO/README.md")" = readme ]
}

@test "a root-owner naming another upstream declines the hallway of this one" {
	second_upstream
	settings "root-owner winux"
	upstream README.md "their readme"
	upstream Unix/engine.sh "engine v2"
	merge foundation
	[ "$status" -eq 0 ]
	[ "$(staged)" = "Unix/engine.sh " ]
}

@test "a take line adopts a hallway path of that upstream only" {
	second_upstream
	settings "take foundation .github/ISSUE_TEMPLATE/" "take winux README.md"
	upstream .github/ISSUE_TEMPLATE/bug.md "bug form"
	upstream .github/FUNDING.yml "funding"
	upstream README.md "their readme"
	merge foundation
	[ "$status" -eq 0 ]
	[ "$(staged)" = ".github/ISSUE_TEMPLATE/bug.md " ]
	[ ! -e "$REPO/.github/FUNDING.yml" ]
	[ "$(cat "$REPO/README.md")" = readme ]
}

@test "a path in another upstream's own room is declined, even when this upstream owns the root" {
	second_upstream
	settings "root-owner foundation"
	upstream Windows/Script.ps1 "their script"
	upstream README.md "their readme"
	merge foundation
	[ "$status" -eq 0 ]
	[ "$(staged)" = "README.md " ]
	[ ! -e "$REPO/Windows/Script.ps1" ]
	[ -f "$REPO/Windows/PowerShell/Upstream.conf" ]
}

@test "the rules come from the upstream's manifest as the merged commit has it" {
	second_upstream
	manifest "own         Extra/" >"$UPWORK/Unix/config/upstream.conf"
	git -C "$UPWORK" add -A
	git -C "$UPWORK" commit -qm "Own Extra"
	upstream Extra/tool.sh "tool"
	merge foundation
	[ "$status" -eq 0 ]
	[ "$(staged)" = "Extra/tool.sh Unix/config/upstream.conf " ]
}

@test "a conflict in a declined path is put back; one in a taken path is left to resolve" {
	second_upstream
	echo "our readme" >"$REPO/README.md"
	echo "our engine" >"$REPO/Unix/engine.sh"
	git -C "$REPO" commit -qam "Fork edits"
	upstream README.md "their readme"
	upstream Unix/engine.sh "their engine"
	merge foundation
	[ "$status" -eq 1 ]
	merging
	[ "$(git -C "$REPO" diff --name-only --diff-filter=U)" = Unix/engine.sh ]
	[ "$(cat "$REPO/README.md")" = "our readme" ]
	[[ $output == *Unix/engine.sh* ]]
}

@test "--dry-run merges nothing, even on a dirty tree, and lists the declined paths and mirror drift" {
	second_upstream
	upstream Unix/engine.sh "engine v2"
	upstream README.md "their readme"
	upstream LICENSE "license v2"
	echo "work in progress" >>"$REPO/README.md"
	merge foundation --dry-run
	[ "$status" -eq 0 ]
	! merging || false
	[ -z "$(staged)" ]
	[ "$(cat "$REPO/Unix/engine.sh")" = engine ]
	[ "$(tail -n1 "$REPO/README.md")" = "work in progress" ]
	[[ $output == *README.md* ]]
	[[ $output == *LICENSE* ]]
	[[ $output != *Unix/engine.sh* ]]
}

@test "the Windows -WhatIf is the dry run and -Name the upstream" {
	upstream Unix/engine.sh "engine v2"
	merge -Name foundation -WhatIf
	[ "$status" -eq 0 ]
	! merging || false
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
	merging
}

@test "a missing remote, or one of that name pointing elsewhere, prints the git remote command and changes nothing" {
	git -C "$REPO" remote remove foundation
	config=$(cat "$REPO/.git/config")
	merge foundation
	[ "$status" -eq 1 ]
	[[ $output == *"git remote add foundation $UPSTREAM"* ]]
	[ "$(cat "$REPO/.git/config")" = "$config" ]
	git -C "$REPO" remote add foundation "$BATS_TEST_TMPDIR/elsewhere.git"
	config=$(cat "$REPO/.git/config")
	merge foundation
	[ "$status" -eq 1 ]
	[[ $output == *"git remote set-url foundation $UPSTREAM"* ]]
	[ "$(cat "$REPO/.git/config")" = "$config" ]
	! merging || false
}

@test "the remote is found by its URL under another name" {
	git -C "$REPO" remote rename foundation macupstream
	upstream Unix/engine.sh "engine v2"
	merge foundation
	[ "$status" -eq 0 ]
	[ "$(staged)" = "Unix/engine.sh " ]
	git -C "$REPO" remote | grep -qx macupstream
	! git -C "$REPO" remote | grep -qx foundation || false
	git -C "$REPO" show-ref --verify -q refs/remotes/macupstream/master
}

@test "only the upstream's prefixed tags are fetched" {
	git -C "$UPWORK" tag -a foundation/v0.2.0 -m "foundation/v0.2.0"
	git -C "$UPWORK" tag v9.9.9
	git -C "$UPWORK" push -q origin --tags 2>/dev/null
	upstream Unix/engine.sh "engine v2"
	merge foundation
	[ "$status" -eq 0 ]
	git -C "$REPO" show-ref --verify -q refs/tags/foundation/v0.2.0
	! git -C "$REPO" show-ref --verify -q refs/tags/v9.9.9 || false
}

@test "nothing new upstream is a success with nothing in progress" {
	merge foundation
	[ "$status" -eq 0 ]
	! merging || false
}

@test "an unknown upstream, a missing branch and two names are refused" {
	merge nosuchupstream
	[ "$status" -eq 1 ]
	merge foundation --branch nosuchbranch
	[ "$status" -eq 1 ]
	merge foundation other
	[ "$status" -eq 1 ]
	merge
	[ "$status" -eq 1 ]
	! merging || false
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
	[[ $output == *'git merge -s ours --allow-unrelated-histories -m "Bridge alone as an upstream" alone/master'* ]]
	! merging || false
}

@test "the suggested commit message names the newest release of the upstream's changelog" {
	upstream Unix/engine.sh "engine v2"
	merge foundation
	[ "$status" -eq 0 ]
	[[ $output == *"Merge foundation master: unreleased changes"* ]]
	git -C "$REPO" merge --abort
	upstream Unix/CHANGELOG.md "$(printf '# Changelog\n\n## [Unreleased]\n\n## [0.3.0] - 2026-02-01\n\n## [0.2.0] - 2026-01-01')"
	merge foundation
	[ "$status" -eq 0 ]
	[[ $output == *"Merge foundation master: 0.3.0"* ]]
}

@test "the push step branches off master first, and pushes any other branch as it is" {
	upstream Unix/engine.sh "engine v2"
	merge foundation
	[ "$status" -eq 0 ]
	[[ $output == *"git switch -c merge-foundation"* ]]
	[[ $output == *"git push -u origin merge-foundation"* ]]
	git -C "$REPO" merge --abort
	git -C "$REPO" switch -q -c feature
	merge foundation
	[ "$status" -eq 0 ]
	[[ $output == *"git push -u origin feature"* ]]
}
