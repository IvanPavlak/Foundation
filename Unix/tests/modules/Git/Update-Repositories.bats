#!/usr/bin/env bats
# Update-Repositories against throwaway repositories (real git, user config never read): clones
# what is missing, and updates an existing checkout without ever losing or misplacing local work -
# the scenarios of the Windows Update-Repository data-safety suites.

# bats file_tags=integration
load ../../helpers
load ../../git

setup() {
	setup_foundation
	git_sandbox
	export FOUNDATION_CONFIG_DIR=$BATS_TEST_TMPDIR/config
	mkdir -p "$FOUNDATION_CONFIG_DIR" "$BATS_TEST_TMPDIR/notrepo"
	echo keep >"$BATS_TEST_TMPDIR/notrepo/mine.txt"
	# A second clone that plays "someone else pushing to origin".
	OTHER=$BATS_TEST_TMPDIR/other
	git clone -q "$ORIGIN" "$OTHER" 2>/dev/null
	conf ""
}

# repositories.conf: the top-level lines given, then [Demo] with Repo = the sandbox clone.
conf() {
	{
		printf '%s\n' "$@"
		printf '[Demo]\nRepo  %s  %s\n' "$(origin_url Repo)" "$REPO"
	} >"$FOUNDATION_CONFIG_DIR/repositories.conf"
}
# Commit FILE with CONTENT on master in the other clone and push it.
upstream() {
	git -C "$OTHER" checkout -q master
	git -C "$OTHER" pull -q origin master 2>/dev/null
	printf '%s\n' "$2" >"$OTHER/$1"
	git -C "$OTHER" add -f "$1"
	git -C "$OTHER" commit -qm "Upstream $1"
	git -C "$OTHER" push -q origin master 2>/dev/null
}
update() { run "${BASH:-bash}" "$bin/Update-Repositories" "$@"; }

@test "a group clones what is missing and leaves a non-checkout folder alone" {
	printf '[Demo]\nFresh  %s  %s/fresh\nOther  %s  %s/notrepo\n' "$(origin_url Fresh)" "$BATS_TEST_TMPDIR" "$(origin_url Other)" "$BATS_TEST_TMPDIR" >"$FOUNDATION_CONFIG_DIR/repositories.conf"
	update Demo
	[ -f "$BATS_TEST_TMPDIR/fresh/file.txt" ]
	[ -f "$BATS_TEST_TMPDIR/notrepo/mine.txt" ]
	[ ! -e "$BATS_TEST_TMPDIR/notrepo/.git" ]
	[ "$status" -eq 1 ]
}

@test "a repository is printed under the name of its URL, like Get-RepositoryName" {
	printf '[Demo]\nAlias  %s  %s\n' "$(origin_url Real_Name)" "$REPO" >"$FOUNDATION_CONFIG_DIR/repositories.conf"
	update Alias --quiet
	[ "$status" -eq 0 ]
	[[ $output == *"[Real_Name] master - up to date"* ]]
	[[ $output != *"[Alias]"* ]]
}

@test "quiet lines of one group follow each other without blank lines" {
	printf '[Demo]\nRepo  %s  %s\nSecond  %s  %s/second\n' "$(origin_url Repo)" "$REPO" "$(origin_url Second)" "$BATS_TEST_TMPDIR" >"$FOUNDATION_CONFIG_DIR/repositories.conf"
	update Demo --quiet --no-clone
	[[ $output == *$'up to date\n=> [Second] not cloned'* ]]
}

@test "an unknown group or repository is reported, nothing is cloned" {
	update NoSuchGroupAnywhere
	[[ $output == *"No group or repository named [NoSuchGroupAnywhere]"* ]]
}

@test "a clean checkout is fast-forwarded, quiet prints one line and the totals" {
	upstream new.txt hello
	update Demo --quiet
	[ "$status" -eq 0 ]
	[ -f "$REPO/new.txt" ]
	[[ $output == *"[Repo] master - updated"* ]]
	[[ $output == *"Repositories => 1 updated, 0 up to date, 0 need attention, 0 skipped"* ]]
	update Demo --quiet
	[[ $output == *"[Repo] master - up to date"* ]]
}

@test "staged, unstaged and untracked changes come back exactly, staged ones still staged" {
	upstream new.txt hello
	echo staged >"$REPO/staged.txt"
	git -C "$REPO" add staged.txt
	echo changed >"$REPO/file.txt"
	echo untracked >"$REPO/untracked.txt"
	update Demo
	[ "$status" -eq 0 ]
	[ -f "$REPO/new.txt" ]
	[ "$(cat "$REPO/file.txt")" = changed ]
	[ "$(cat "$REPO/untracked.txt")" = untracked ]
	git -C "$REPO" diff --cached --name-only | grep -qx staged.txt
	[ -z "$(git -C "$REPO" stash list)" ]
}

@test "an ignored local file is never overwritten by a file upstream starts tracking" {
	echo local.cfg >"$REPO/.gitignore"
	git -C "$REPO" add .gitignore && git -C "$REPO" commit -qm ignore && git -C "$REPO" push -q origin master 2>/dev/null
	echo mine >"$REPO/local.cfg"
	upstream local.cfg theirs
	before=$(git -C "$REPO" rev-parse HEAD)
	update Demo --quiet
	[ "$status" -eq 1 ]
	[ "$(cat "$REPO/local.cfg")" = mine ]
	[ "$(git -C "$REPO" rev-parse HEAD)" = "$before" ]
	[[ $output == *"could not fast-forward, nothing changed"* ]]
}

@test "a merge in progress is left alone" {
	upstream new.txt hello
	git -C "$REPO" rev-parse HEAD >"$REPO/.git/MERGE_HEAD"
	before=$(git -C "$REPO" rev-parse HEAD)
	update Demo --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"operation in progress, nothing touched"* ]]
	[ "$(git -C "$REPO" rev-parse HEAD)" = "$before" ]
	[ ! -f "$REPO/new.txt" ]
}

@test "a detached HEAD is skipped and stays where it is" {
	git -C "$REPO" checkout -q --detach
	upstream new.txt hello
	update Demo --quiet
	[ "$status" -eq 0 ]
	[[ $output == *"detached HEAD, nothing to pull"* ]]
	[ "$(git -C "$REPO" rev-parse --abbrev-ref HEAD)" = HEAD ]
}

@test "a folder inside another repository is refused, the enclosing repository is not updated" {
	mkdir -p "$REPO/sub" && echo x >"$REPO/sub/x.txt"
	printf '[Demo]\nSub  %s  %s/sub\n' "$(origin_url Sub)" "$REPO" >"$FOUNDATION_CONFIG_DIR/repositories.conf"
	upstream new.txt hello
	update Demo --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"not the top of a git repository"* ]]
	[ ! -f "$REPO/new.txt" ]
}

@test "a branch origin does not have is skipped, local changes restored" {
	git -C "$REPO" checkout -q -b local-only
	echo wip >"$REPO/wip.txt"
	update Demo --quiet
	[ "$status" -eq 0 ]
	[[ $output == *"[Repo] local-only - not on origin, nothing to pull"* ]]
	[ -f "$REPO/wip.txt" ]
	[ -z "$(git -C "$REPO" stash list)" ]
}

@test "an unreachable origin is reported, not taken for up to date" {
	mv "$ORIGIN" "$ORIGIN.gone"
	echo wip >"$REPO/wip.txt"
	update Demo --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"could not fetch from origin"* ]]
	[ -f "$REPO/wip.txt" ]
}

@test "the user's own older stash is never applied or dropped" {
	echo older >"$REPO/file.txt"
	git -C "$REPO" stash push -q -m "mine"
	upstream new.txt hello
	echo current >"$REPO/untracked.txt"
	update Demo
	[ "$status" -eq 0 ]
	[ "$(git -C "$REPO" stash list | wc -l | tr -d ' ')" -eq 1 ]
	git -C "$REPO" stash list | grep -q mine
	[ "$(cat "$REPO/file.txt")" = one ]
	[ -f "$REPO/untracked.txt" ]
}

@test "a stash that cannot be restored cleanly is kept and named" {
	echo mine >"$REPO/file.txt"
	upstream file.txt theirs
	update Demo --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"are kept in stash [master_"* ]]
	git -C "$REPO" stash list | grep -q "master_"
}

@test "--include-default-branch fast-forwards master while another branch is checked out" {
	git -C "$REPO" checkout -q -b feature
	git -C "$REPO" push -q origin feature 2>/dev/null
	echo wip >"$REPO/wip.txt"
	upstream new.txt hello
	update Demo --quiet --include-default-branch
	[ "$status" -eq 0 ]
	[[ $output == *"[Repo] feature - up to date, master fast-forwarded"* ]]
	[ "$(git -C "$REPO" rev-parse master)" = "$(git -C "$ORIGIN" rev-parse master)" ]
	[ "$(git -C "$REPO" rev-parse --abbrev-ref HEAD)" = feature ]
	[ -f "$REPO/wip.txt" ]
	[ ! -f "$REPO/new.txt" ]
}

@test "a default branch with local commits is left untouched; the config switch and its override" {
	git -C "$REPO" checkout -q -b feature
	git -C "$REPO" push -q origin feature 2>/dev/null
	git -C "$REPO" checkout -q master
	echo local >"$REPO/local.txt" && git -C "$REPO" add local.txt && git -C "$REPO" commit -qm local
	git -C "$REPO" checkout -q feature
	upstream new.txt hello
	conf "include-default-branch on"
	update Demo --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"master has local commits, left untouched"* ]]
	update Demo --quiet --no-include-default-branch
	[ "$status" -eq 0 ]
	[[ $output != *"master"* ]]
}

@test "--no-clone reports a missing repository as skipped, quiet runs print a heading per group" {
	printf '[One]\nRepo  %s  %s\n[Two]\nFresh  %s  %s/fresh\n' "$(origin_url Repo)" "$REPO" "$(origin_url Fresh)" "$BATS_TEST_TMPDIR" >"$FOUNDATION_CONFIG_DIR/repositories.conf"
	update --all --no-clone --quiet
	[ "$status" -eq 0 ]
	[[ $output == *"[Fresh] not cloned on this machine - skipped"* ]]
	[[ $output == *"One"* ]]
	[[ $output == *"Two"* ]]
	[ ! -e "$BATS_TEST_TMPDIR/fresh" ]
}

@test "a comma list names several repositories; an unknown flag updates nothing" {
	printf '[Demo]\nRepo  %s  %s\nSecond  %s  %s/second\n' "$(origin_url Repo)" "$REPO" "$(origin_url Second)" "$BATS_TEST_TMPDIR" >"$FOUNDATION_CONFIG_DIR/repositories.conf"
	update -Repositories Repo,Second --quiet --no-clone
	[[ $output == *"[Repo] master - up to date"* ]]
	[[ $output == *"[Second] not cloned"* ]]
	update Repo --no-clnoe
	[ "$status" -eq 1 ]
	[[ $output == *"Unknown argument => --no-clnoe"* ]]
	[[ $output != *"up to date"* ]]
}

@test "--archive writes a history-less copy to the Desktop, never the configured path" {
	rm -rf "$REPO"
	update Demo --archive
	[ "$status" -eq 0 ]
	[ -f "$HOME/Desktop/Repo/file.txt" ]
	[ ! -e "$HOME/Desktop/Repo/.git" ]
	[ ! -e "$REPO" ]
}

@test "--in-current-directory clones into ./NAME, and with --archive copies there" {
	rm -rf "$REPO"
	mkdir -p "$BATS_TEST_TMPDIR/here"
	cd "$BATS_TEST_TMPDIR/here"
	update Demo --in-current-directory
	[ "$status" -eq 0 ]
	[ -d "$BATS_TEST_TMPDIR/here/Repo/.git" ]
	[ ! -e "$REPO" ]
	mkdir -p "$BATS_TEST_TMPDIR/there"
	cd "$BATS_TEST_TMPDIR/there"
	update Demo --archive --in-current-directory
	[ "$status" -eq 0 ]
	[ -f "$BATS_TEST_TMPDIR/there/Repo/file.txt" ]
	[ ! -e "$BATS_TEST_TMPDIR/there/Repo/.git" ]
	[ ! -e "$HOME/Desktop/Repo" ]
}

# Commit FILE with CONTENT on the checked-out branch of the sandbox clone (not pushed).
local_commit() {
	printf '%s\n' "$2" >"$REPO/$1"
	git -C "$REPO" add "$1"
	git -C "$REPO" commit -qm "Local $1"
}
# A branch `side` and master that both change file.txt (local commits only), master checked out.
conflicting_side() {
	git -C "$REPO" checkout -q -b side
	local_commit file.txt side
	git -C "$REPO" checkout -q master
	local_commit file.txt master
}
# A stand-in for git, first on PATH, that runs BODY (sh, the arguments in "$@") before handing the
# call to the real git. Usage: git_wrapper 'BODY'
git_wrapper() {
	local real dir=$BATS_TEST_TMPDIR/tools
	real=$(command -v git)
	mkdir -p "$dir"
	printf '#!/bin/sh\nreal='"'%s'"'\n%s\nexec "$real" "$@"\n' "$real" "$1" >"$dir/git"
	chmod +x "$dir/git"
	export PATH="$dir:$PATH"
}

@test "a repository line ending in shallow is cloned --depth 1 and keeps its .git; an unmarked one gets the history" {
	upstream second.txt two
	printf '[Demo]\nNotes  %s  %s/notes  shallow\nFull  %s  %s/full\n' "$(origin_url Notes)" "$BATS_TEST_TMPDIR" "$(origin_url Full)" "$BATS_TEST_TMPDIR" >"$FOUNDATION_CONFIG_DIR/repositories.conf"
	update Demo --quiet
	[ "$status" -eq 0 ]
	[ "$(git -C "$BATS_TEST_TMPDIR/notes" rev-parse --is-shallow-repository)" = true ]
	[ "$(git -C "$BATS_TEST_TMPDIR/notes" rev-list --count HEAD)" -eq 1 ]
	[ -f "$BATS_TEST_TMPDIR/notes/second.txt" ]
	[ "$(git -C "$BATS_TEST_TMPDIR/full" rev-parse --is-shallow-repository)" = false ]
	[ "$(git -C "$BATS_TEST_TMPDIR/full" rev-list --count HEAD)" -eq 2 ]
}

@test "--group takes group names only: an unknown one aborts with the configured groups, nothing updated" {
	upstream new.txt hello
	update --group Demo,Nope --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"Unknown repository group [Nope] in --group - nothing updated. Configured groups => [Demo]"* ]]
	[[ $output != *"[Repo]"* ]]
	[ ! -f "$REPO/new.txt" ]
	update -Group Repo --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"Unknown repository group [Repo]"* ]]
}

@test "--group picks a group, --repositories a repository of the same name, a bare name the group" {
	printf '[Repo]\nSecond  %s  %s/second\n[Demo]\nRepo  %s  %s\n' "$(origin_url Second)" "$BATS_TEST_TMPDIR" "$(origin_url Repo)" "$REPO" >"$FOUNDATION_CONFIG_DIR/repositories.conf"
	update --group repo --quiet --no-clone
	[[ $output == *"[Second] not cloned"* ]]
	[[ $output != *"[Repo] master"* ]]
	update --repositories Repo --quiet --no-clone
	[ "$status" -eq 0 ]
	[[ $output == *"[Repo] master - up to date"* ]]
	[[ $output != *"[Second]"* ]]
	update Repo --quiet --no-clone
	[[ $output == *"[Second] not cloned"* ]]
	update --repositories Nope --quiet
	[[ $output == *"No repository named [Nope]"* ]]
}

@test "--repository-url with --local-path clones one repository outside the file, then updates it" {
	target=$BATS_TEST_TMPDIR/custom
	update -RepositoryUrl "$(origin_url Custom)" -LocalPath "$target" --quiet
	[ "$status" -eq 0 ]
	[[ $output == *"[Custom] cloned"* ]]
	[ -d "$target/.git" ]
	upstream new.txt hello
	update --repository-url "$(origin_url Custom)" --local-path "$target" --quiet
	[ "$status" -eq 0 ]
	[[ $output == *"[Custom] master - updated"* ]]
	[ -f "$target/new.txt" ]
}

@test "the modes stay apart: half a URL/path pair, a pair with names, --group with --repositories" {
	update --repository-url "$(origin_url Custom)"
	[ "$status" -ne 0 ]
	[[ $output == *"--repository-url and --local-path go together"* ]]
	update Demo --repository-url "$(origin_url Custom)" --local-path "$BATS_TEST_TMPDIR/custom"
	[ "$status" -ne 0 ]
	update --group Demo --repositories Repo
	[ "$status" -ne 0 ]
	[[ $output == *"separate modes"* ]]
	update --all --group Demo
	[ "$status" -ne 0 ]
	[ ! -e "$BATS_TEST_TMPDIR/custom" ]
}

@test "each folder runs once: a repository in two groups once, two entries sharing only a name both" {
	printf '[One]\nRepo  %s  %s\nTwin  %s  %s/a\n[Two]\nRepo  %s  %s\nTwin  %s  %s/b\n' \
		"$(origin_url Repo)" "$REPO" "$(origin_url Twin)" "$BATS_TEST_TMPDIR" \
		"$(origin_url Repo)" "$REPO" "$(origin_url Twin)" "$BATS_TEST_TMPDIR" >"$FOUNDATION_CONFIG_DIR/repositories.conf"
	update --all --quiet --no-clone
	[ "$status" -eq 0 ]
	[ "$(grep -c '\[Repo\] master - up to date' <<<"$output")" -eq 1 ]
	[ "$(grep -c '\[Twin\] not cloned' <<<"$output")" -eq 2 ]
	[[ $output == *"1 up to date, 0 need attention, 2 skipped"* ]]
}

@test "--all runs the groups and their repositories in file order" {
	printf '[Zeta]\nSecond  %s  %s/second\n[Alpha]\nRepo  %s  %s\nThird  %s  %s/third\n' \
		"$(origin_url Second)" "$BATS_TEST_TMPDIR" "$(origin_url Repo)" "$REPO" "$(origin_url Third)" "$BATS_TEST_TMPDIR" >"$FOUNDATION_CONFIG_DIR/repositories.conf"
	update --all --quiet --no-clone
	order=$(grep -oE '\[(Second|Repo|Third)\]' <<<"$output" | tr '\n' ' ')
	[ "$order" = "[Second] [Repo] [Third] " ]
}

@test "S13: a resolved but uncommitted merge, and its resolution, are left alone" {
	conflicting_side
	! git -C "$REPO" merge -q side >/dev/null 2>&1 || false
	echo resolved >"$REPO/file.txt"
	git -C "$REPO" add file.txt
	before=$(git -C "$REPO" rev-parse HEAD)
	upstream new.txt hello
	update Demo --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"operation in progress, nothing touched"* ]]
	[ "$(git -C "$REPO" rev-parse HEAD)" = "$before" ]
	[ "$(cat "$REPO/file.txt")" = resolved ]
	git -C "$REPO" diff --cached --name-only | grep -qx file.txt
	[ -f "$REPO/.git/MERGE_HEAD" ]
	[ -z "$(git -C "$REPO" stash list)" ]
}

@test "S14-S16: a rebase, a cherry-pick and a bisect in progress are left alone" {
	conflicting_side
	upstream new.txt hello
	git -C "$REPO" checkout -q side
	! git -C "$REPO" rebase master >/dev/null 2>&1 || false
	update Demo --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"operation in progress, nothing touched"* ]]
	[ -d "$REPO/.git/rebase-merge" ] || [ -d "$REPO/.git/rebase-apply" ]
	git -C "$REPO" rebase --abort
	git -C "$REPO" checkout -q master
	! git -C "$REPO" cherry-pick side >/dev/null 2>&1 || false
	before=$(git -C "$REPO" rev-parse HEAD)
	update Demo --quiet
	[ "$status" -eq 1 ]
	[ -f "$REPO/.git/CHERRY_PICK_HEAD" ]
	[ "$(git -C "$REPO" rev-parse HEAD)" = "$before" ]
	git -C "$REPO" cherry-pick --abort
	git -C "$REPO" bisect start >/dev/null 2>&1
	update Demo --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"operation in progress, nothing touched"* ]]
	[ ! -f "$REPO/new.txt" ]
	[ -z "$(git -C "$REPO" stash list)" ]
}

@test "unresolved conflicts without a merge (a stash pop that conflicted) are left alone" {
	echo mine >"$REPO/file.txt"
	git -C "$REPO" stash push -q
	local_commit file.txt theirs
	! git -C "$REPO" stash pop >/dev/null 2>&1 || false
	[ -n "$(git -C "$REPO" ls-files --unmerged)" ]
	upstream new.txt hello
	update Demo --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"operation in progress, nothing touched"* ]]
	[ "$(git -C "$REPO" stash list | wc -l | tr -d ' ')" -eq 1 ]
	[ ! -f "$REPO/new.txt" ]
}

@test "S07: an untracked file where upstream adds the same path is kept" {
	echo mine >"$REPO/added.txt"
	upstream added.txt theirs
	update Demo --quiet
	if [ "$(cat "$REPO/added.txt")" != mine ]; then
		[[ $output == *"are kept in stash [master_"* ]]
		[ "$(git -C "$REPO" show 'stash@{0}^3:added.txt')" = mine ]
	fi
}

@test "S09: a diverged branch keeps its local commit and changes, nothing is merged" {
	local_commit lc.txt "local commit"
	echo mine >"$REPO/b.txt"
	upstream new.txt hello
	before=$(git -C "$REPO" rev-parse HEAD)
	update Demo --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"[Repo] master - could not fast-forward, nothing changed"* ]]
	[ "$(git -C "$REPO" rev-parse HEAD)" = "$before" ]
	[ "$(cat "$REPO/b.txt")" = mine ]
	[ ! -f "$REPO/new.txt" ]
	[ -z "$(git -C "$REPO" stash list)" ]
}

@test "S10: a branch that is only ahead keeps its unpushed commit and is up to date" {
	local_commit lc.txt "local commit"
	before=$(git -C "$REPO" rev-parse HEAD)
	update Demo --quiet
	[ "$status" -eq 0 ]
	[[ $output == *"[Repo] master - up to date"* ]]
	[ "$(git -C "$REPO" rev-parse HEAD)" = "$before" ]
}

@test "S25: a default branch checked out with changes in another worktree is never touched" {
	git -C "$REPO" checkout -q -b feature
	git -C "$REPO" push -q origin feature 2>/dev/null
	wt=$BATS_TEST_TMPDIR/wt-master
	git -C "$REPO" worktree add -q "$wt" master 2>/dev/null
	echo mine >"$wt/b.txt"
	echo changed >"$wt/file.txt"
	wt_before=$(git -C "$wt" rev-parse HEAD)
	upstream new.txt hello
	update Demo --quiet --include-default-branch
	[[ $output == *"[Repo] feature - up to date"* ]]
	[ "$(git -C "$wt" rev-parse HEAD)" = "$wt_before" ]
	[ "$(cat "$wt/b.txt")" = mine ]
	[ "$(cat "$wt/file.txt")" = changed ]
	[ ! -f "$wt/new.txt" ]
}

@test "S28: another command stashing in between keeps its stash; this run restores only its own" {
	echo mine >"$REPO/b.txt"
	upstream new.txt hello
	git_wrapper 'if [ "$1" = -C ] && [ "$3" = fetch ] && [ ! -e "'"$BATS_TEST_TMPDIR"'/intruded" ]; then
	: >"'"$BATS_TEST_TMPDIR"'/intruded"
	echo intruder >"$2/intruder.txt"
	"$real" -C "$2" stash push -q --include-untracked -m "INTRUDER STASH"
fi'
	update Demo --quiet
	[ "$status" -eq 0 ]
	[[ $output == *"[Repo] master - updated"* ]]
	[ "$(cat "$REPO/b.txt")" = mine ]
	[ -f "$REPO/new.txt" ]
	[ ! -e "$REPO/intruder.txt" ]
	[ "$(git -C "$REPO" stash list | wc -l | tr -d ' ')" -eq 1 ]
	git -C "$REPO" stash list | grep -q "INTRUDER STASH"
}

@test "StashMissing: a stash another command took is reported, the work stays in the tree" {
	echo mine >"$REPO/b.txt"
	upstream new.txt hello
	git_wrapper 'if [ "$1" = -C ] && [ "$3" = fetch ]; then "$real" -C "$2" stash pop -q; fi'
	update Demo --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"its stash was taken by another git command"* ]]
	[ "$(cat "$REPO/b.txt")" = mine ]
}

@test "StashFailed: a stash push that fails skips the update and keeps the work" {
	echo mine >"$REPO/b.txt"
	echo changed >"$REPO/file.txt"
	upstream new.txt hello
	before=$(git -C "$REPO" rev-parse HEAD)
	git_wrapper 'case " $* " in *" stash push "*) exit 1 ;; esac'
	update Demo --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"local changes could not be stashed - skipped"* ]]
	[ "$(git -C "$REPO" rev-parse HEAD)" = "$before" ]
	[ "$(cat "$REPO/b.txt")" = mine ]
	[ "$(cat "$REPO/file.txt")" = changed ]
	[ -z "$(git -C "$REPO" stash list)" ]
}

@test "a default branch with no local branch is reported Missing and needs no attention" {
	git -C "$REPO" checkout -q -b feature
	git -C "$REPO" push -q origin feature 2>/dev/null
	git -C "$REPO" branch -q -D master
	update Demo --quiet --include-default-branch
	[ "$status" -eq 0 ]
	[[ $output == *"[Repo] feature - up to date, no local master"* ]]
	! git -C "$REPO" show-ref --verify --quiet refs/heads/master || false
}

@test "S33: --archive over an existing folder of the same name skips it and keeps its .git" {
	mkdir -p "$HOME/Desktop"
	git clone -q "$ORIGIN" "$HOME/Desktop/Repo" 2>/dev/null
	echo mine >"$HOME/Desktop/Repo/mine.txt"
	update Demo --archive
	[ "$status" -eq 0 ]
	[[ $output == *"Skipping [Repo] => already exists at [$HOME/Desktop/Repo]"* ]]
	[ -d "$HOME/Desktop/Repo/.git" ]
	[ "$(cat "$HOME/Desktop/Repo/mine.txt")" = mine ]
}

@test "repo_format_result: every outcome lands in its category" {
	foundation_load repository
	while read -r outcome default category; do
		repo_result Repo "$outcome"
		[ "$default" = - ] || {
			REPO_DEFAULT_BRANCH=master
			REPO_DEFAULT_OUTCOME=$default
		}
		repo_format_result
		[ "$REPO_CATEGORY" = "$category" ] || {
			echo "$outcome/$default: $REPO_CATEGORY, expected $category"
			return 1
		}
		if [ "$category" = Attention ]; then [ "$REPO_LEVEL" = Warning ]; else [ "$REPO_LEVEL" = Success ]; fi
	done <<'TABLE'
Updated - Updated
Cloned - Updated
UpToDate - UpToDate
NotCloned - Skipped
NotConfigured - Skipped
NoUpstream - Skipped
Detached - Skipped
FetchFailed - Attention
Conflict - Attention
Busy - Attention
NotARepository - Attention
StashFailed - Attention
StashConflict - Attention
StashMissing - Attention
Error - Attention
UpToDate Updated UpToDate
UpToDate Missing UpToDate
UpToDate Diverged Attention
UpToDate Failed Attention
UpToDate Unresolved Attention
TABLE
}

@test "an SSH remote is printed under its repository name, like Get-RepositoryName" {
	printf '[Demo]\nAlias  git@host.invalid:Owner/My_Repo.git  %s/missing\nPlain  ssh://git@host.invalid/Owner/Other  %s/missing-too\n' "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR" >"$FOUNDATION_CONFIG_DIR/repositories.conf"
	update Demo --quiet --no-clone
	[ "$status" -eq 0 ]
	[[ $output == *"[My_Repo] not cloned"* ]]
	[[ $output == *"[Other] not cloned"* ]]
	[[ $output != *"[Alias]"* ]]
	[ ! -e "$BATS_TEST_TMPDIR/missing" ]
	[ ! -e "$BATS_TEST_TMPDIR/missing-too" ]
}

@test "full URLs are used as they are, a path is appended to the base" {
	foundation_load repository
	[ "$(repo_resolve_url git@host.invalid:Owner/R.git https://example.invalid)" = git@host.invalid:Owner/R.git ]
	[ "$(repo_resolve_url ssh://git@host.invalid/Owner/R.git https://example.invalid)" = ssh://git@host.invalid/Owner/R.git ]
	[ "$(repo_resolve_url git://host.invalid/Owner/R.git https://example.invalid)" = git://host.invalid/Owner/R.git ]
	[ "$(repo_resolve_url https://host.invalid/Owner/R.git https://example.invalid)" = https://host.invalid/Owner/R.git ]
	[ "$(repo_resolve_url /Owner/R.git https://example.invalid)" = https://example.invalid/Owner/R.git ]
}
