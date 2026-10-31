#!/usr/bin/env bats
# The repository policy matrix: AI/Hooks/ai-repository-policy.sh and the policy part of
# AI/Hooks/ai-ownership-guard.sh, fed Claude Code hook JSON directly (an agent refuses a dangerous
# command before the hook sees it, so a live session cannot test the hook). The port of WinuX's
# AiRepositoryPolicy.Tests.ps1, case for case, several hook calls per test (one bash process each).
# The hooks run under AI_HOOK_BASH (default /bin/bash, the 3.2 a Mac without Homebrew on Claude
# Code's PATH runs them with) and the system's awk, sed, grep and tr (BSD on a Mac); run the file
# once more with AI_HOOK_BASH set to Homebrew's bash 5 for the other half.

load helpers

setup_file() {
	export POLICY_ROOT="$BATS_FILE_TMPDIR/policy"
	mkdir -p "$POLICY_ROOT/bin" "$POLICY_ROOT/outside"
	# Two repositories with the same origin: one on a feature branch, one on the default branch.
	local pair
	for pair in feature:feature onmaster:master; do
		git init -q -b "${pair#*:}" "$POLICY_ROOT/${pair%%:*}"
		git -C "$POLICY_ROOT/${pair%%:*}" remote add origin https://github.com/MyUser/MyProject.git
	done
}

setup() {
	setup_foundation
	HOOKS="$(dirname "$UNIX_DIR")/AI/Hooks"
	POLICY_HOOK="$HOOKS/ai-repository-policy.sh"
	GUARD="$HOOKS/ai-ownership-guard.sh"
	HOOK_BASH=${AI_HOOK_BASH:-/bin/bash}
	CONF="$BATS_TEST_TMPDIR/ai-profile.conf"
	FEATURE="$POLICY_ROOT/feature"
	ON_MASTER="$POLICY_ROOT/onmaster"
	OUTSIDE="$POLICY_ROOT/outside"
	CALLS=0
	fake_gh red
}

# Writes ai-profile.conf, one argument per line (none: an empty file). Usage: policy_conf LINE...
policy_conf() {
	if [ $# -eq 0 ]; then : >"$CONF"; else printf '%s\n' "$@" >"$CONF"; fi
}

# The fake gh: `gh pr checks` answers green (exit 0), none (no checks reported, exit 1) or red.
# Usage: fake_gh green|none|red
fake_gh() {
	case $1 in
		green) body='exit 0' ;;
		none) body="echo \"no checks reported on the 'feature' branch\" >&2; exit 1" ;;
		*) body='echo "some checks were not successful" >&2; exit 1' ;;
	esac
	printf '#!/bin/sh\n%s\n' "$body" >"$POLICY_ROOT/bin/gh"
	chmod +x "$POLICY_ROOT/bin/gh"
}

# TEXT as the body of a JSON string.
json_escape() {
	local s=$1
	s=${s//\\/\\\\}
	s=${s//\"/\\\"}
	s=${s//$'\n'/\\n}
	s=${s//$'\t'/\\t}
	printf '%s' "$s"
}

# Runs a hook on one hook input and prints its decision: allow, deny: REASON or block: REASON.
# Each call is a new session (CALLS counts them, so call it outside $(...) or bump CALLS first), so
# no level is cached between calls. Usage: decide COMMAND [TOOL [CWD [HOOK [EVENT [UNATTENDED]]]]]
decide() {
	local command=$1 tool=${2:-Bash} cwd=${3:-$FEATURE} hook=${4:-$POLICY_HOOK} event=${5:-} unattended=${6:-} json output
	json=$(printf '{"session_id":"s%s-%s-%s","cwd":"%s","tool_name":"%s","tool_input":{"command":"%s"}}' \
		"$BATS_TEST_NUMBER" "$CALLS" "$$" "$cwd" "$tool" "$(json_escape "$command")")
	# shellcheck disable=SC2086 # EVENT is one word or none
	output=$(printf '%s' "$json" | env -u AI_UNATTENDED AI_PROFILE_CONF="$CONF" TMPDIR="$BATS_TEST_TMPDIR/tmp" \
		PATH="$POLICY_ROOT/bin:$PATH" ${unattended:+AI_UNATTENDED=$unattended} "$HOOK_BASH" "$hook" $event)
	if [ -z "$output" ]; then
		printf 'allow'
	elif [[ $output == *'"permissionDecisionReason"'* ]]; then
		printf 'deny: %s' "$(printf '%s' "$output" | sed -E 's/.*"permissionDecisionReason":"(.*)"}}$/\1/')"
	else
		printf 'block: %s' "$(printf '%s' "$output" | sed -E 's/.*"reason":"(.*)"}$/\1/')"
	fi
}

# Fails, naming the case, unless the decision on COMMAND matches the glob EXPECTED.
# Usage: expect EXPECTED COMMAND [TOOL [CWD [HOOK [EVENT [UNATTENDED]]]]]
expect() {
	local expected=$1 actual
	shift
	CALLS=$((CALLS + 1))
	actual=$(decide "$@")
	# shellcheck disable=SC2053 # EXPECTED is a glob
	[[ $actual == $expected ]] && return 0
	printf 'case    : %s (tool %s)\nexpected: %s\nactual  : %s\n' "$1" "${2:-Bash}" "$expected" "$actual" >&2
	return 1
}

# The always-denied list and the prose cases at LEVEL. Usage: always_denied LEVEL
always_denied() {
	policy_conf 'profile Personal' "default-policy $1"
	expect 'deny: *force pushes*' 'git push --force origin feature'
	expect 'deny: *force pushes*' 'git push --force-with-lease'
	expect 'deny: *force pushes*' $'git status\ngit push -f'
	expect 'deny: *force pushes*' 'git push origin +feature'
	expect 'deny: *default branch*' 'git push origin master'
	expect 'deny: *default branch*' 'git push origin HEAD:main'
	expect 'deny: *default branch*' 'git push origin HEAD:refs/heads/master'
	expect 'deny: *default branch*' 'git push origin feature:refs/heads/main'
	expect 'deny: *every branch*' 'git push --all origin'
	expect 'deny: *every branch*' 'git push --mirror origin'
	expect 'deny: *every branch*' "git push origin 'refs/heads/*:refs/heads/*'"
	expect 'deny: *git configuration*' 'git -c push.default=matching push'
	expect 'deny: *GitHub API*' 'gh api -X PUT repos/MyUser/MyProject/pulls/12/merge'
	expect 'deny: *GitHub API*' 'gh api repos/MyUser/MyProject/merges -f base=master -f head=feature'
	expect 'deny: *GitHub API*' 'gh api --method PATCH repos/MyUser/MyProject/git/refs/heads/master -f sha=abc'
	expect 'deny: *GitHub API*' 'gh api -X PUT repos/MyUser/MyProject/contents/README.md -f message=x -f content=eA=='
	expect 'deny: *GitHub API*' "gh api graphql -f query='mutation { mergePullRequest(input: {pullRequestId: \"x\"}) { clientMutationId } }'"
	expect 'deny: *GitHub API*' 'gh api graphql -F query=@merge.graphql'
	expect 'deny: *GitHub repository*' 'gh repo sync MyUser/MyFork'
	expect 'deny: *GitHub repository*' 'gh repo edit --default-branch feature'
	expect 'deny: *gh configuration*' "gh alias set m 'pr merge'"
	expect 'deny: *deleting branches*' 'git branch -D old'
	expect 'deny: *deleting branches*' 'git push origin --delete old'
	expect 'deny: *deleting branches*' 'git push origin :old'
	expect 'deny: *remotes*' 'git remote set-url origin https://example.com/x.git'
	expect 'deny: *upstream*' 'git branch -u origin/master'
	expect 'deny: *upstream*' 'git switch --track origin/master'
	expect 'deny: *--no-track*' 'git switch -c topic origin/master'
	expect 'deny: *git configuration*' 'git config user.name Someone'
	expect 'deny: *force pushes*' 'bash -c "git push --force"'
	expect 'deny: *force pushes*' $'bash <<\'EOF\'\ngit push --force\nEOF'
	expect 'deny: *force pushes*' 'git push --force' PowerShell
}

always_allowed() {
	policy_conf 'profile Personal' "default-policy $1"
	expect allow 'git add -A && git commit -m "Add the thing"'
	expect allow 'git commit -m "Document the Foundation configuration reference"'
	expect allow 'git commit -m "Explain why git push --force is denied"'
	expect allow $'git commit -m "$(cat <<\'EOF\'\nWhy git config and git push --force are denied\n\nEOF\n)"'
	expect allow $'git commit -F - <<\'EOF\'\nNever git push origin master\nEOF'
	expect allow $'git commit -m @\'\nNever git config --global or git push --force\n\'@' PowerShell
	expect allow 'git push -u origin feature'
	expect allow 'git switch -c topic --no-track origin/master'
	expect allow 'git config --get user.name'
	expect allow 'git config --list'
	expect allow 'git status && git log --oneline -5'
	expect allow 'git push origin feature:refs/heads/feature'
	expect allow 'git push origin HEAD'
	expect allow 'git -c core.pager=cat log -1'
	expect allow 'gh api repos/MyUser/MyProject/pulls/12'
	expect allow 'gh api repos/MyUser/MyProject/git/refs/heads/master'
	expect allow 'gh api repos/MyUser/MyProject/contents/README.md'
	expect allow 'gh api -X GET search/issues -f q=repo:MyUser/MyProject'
	expect allow 'gh api repos/MyUser/MyProject/issues/12/comments -f body=Done'
	expect allow 'gh api repos/MyUser/MyProject/statuses/abc -f state=success -f context=local/tests'
	expect allow 'gh repo view MyUser/MyProject'
	expect allow '' Edit
	expect allow '' Write
}

@test "autonomous: the always-denied list, prose and the file tools" {
	always_denied autonomous
	always_allowed autonomous
}

@test "branch: the always-denied list, prose and the file tools" {
	always_denied branch
	always_allowed branch
}

@test "draft: the always-denied list, prose and the file tools" {
	always_denied draft
	always_allowed draft
}

@test "a plain push while the default branch is checked out is denied, naming a feature branch is not" {
	policy_conf 'profile Personal' 'default-policy branch'
	expect 'deny: *checked-out branch is the default branch*' 'git push' Bash "$ON_MASTER"
	expect 'deny: *checked-out branch is the default branch*' 'git push origin HEAD' Bash "$ON_MASTER"
	expect 'deny: *checked-out branch is the default branch*' 'git push -u origin @' Bash "$ON_MASTER"
	expect allow 'git push origin feature' Bash "$ON_MASTER"
}

@test "a push from another folder must name its branch, since the hook cannot see that folder's branch" {
	policy_conf 'profile Personal' 'default-policy branch'
	expect 'deny: *must name its branch*' 'cd ../onmaster && git push'
	expect 'deny: *must name its branch*' 'git -C ../onmaster push origin HEAD'
	expect 'deny: *must name its branch*' 'Set-Location ../onmaster; git push' PowerShell
	expect allow 'cd ../onmaster && git push origin feature'
	expect allow 'git -C ../onmaster push -u origin feature'
}

@test "a merge runs in the folder of the repository it merges, so that repository's level applies" {
	policy_conf 'profile Personal' 'default-policy autonomous'
	fake_gh green
	expect allow 'gh pr merge 12 --squash -R MyUser/MyProject'
	expect allow 'gh pr merge https://github.com/MyUser/MyProject/pull/12 --squash'
	expect 'deny: *another repository*' 'gh pr merge 12 --repo MyUser/OtherProject'
	expect 'deny: *another repository*' 'gh -R MyUser/OtherProject pr merge 12'
	expect 'deny: *another repository*' 'gh pr merge https://github.com/MyUser/OtherProject/pull/12'
	expect 'deny: *another repository*' 'GH_REPO=MyUser/OtherProject gh pr merge 12'
	expect 'deny: *another repository*' 'cd ../other && gh pr merge 12'
	# The flags before the subcommand do not hide a merge from a branch repository.
	policy_conf 'profile Personal' 'default-policy branch'
	expect 'deny: *autonomous repository*' 'gh -R MyUser/MyProject pr merge 12'
	expect 'deny: *autonomous repository*' 'gh pr --repo MyUser/MyProject merge 12'
}

@test "autonomous: a merge needs green checks, or none reported in a merge-without-checks repository" {
	policy_conf 'profile Personal' 'default-policy autonomous'
	fake_gh green
	expect allow 'gh pr merge 12 --squash'
	fake_gh red
	expect 'deny: *every CI check*' 'gh pr merge 12 --squash'
	fake_gh none
	expect 'deny: *every CI check*' 'gh pr merge 12 --squash'
	policy_conf 'profile Personal' 'default-policy autonomous' 'merge-without-checks github.com/myuser/*'
	expect allow 'gh pr merge 12 --squash'
	policy_conf 'profile Personal' 'default-policy autonomous' 'merge-without-checks github.com/myuser/myproject'
	fake_gh red
	expect 'deny: *every CI check*' 'gh pr merge 12 --squash'
	policy_conf 'profile Personal' 'default-policy autonomous'
	expect allow 'gh pr create --title "Add it" --body "Body"'
	expect allow 'gh pr ready 12'
}

@test "branch: opens and readies a pull request, never merges, even with green checks" {
	policy_conf 'profile Personal' 'default-policy branch'
	fake_gh green
	expect allow 'gh pr create --title "Add it" --body "Body"'
	expect allow 'gh pr ready 12'
	expect 'deny: *autonomous repository*' 'gh pr merge 12'
}

@test "draft: opens draft pull requests only, never readies or merges" {
	policy_conf 'profile Personal' 'default-policy draft'
	fake_gh green
	expect allow 'gh pr create --draft --title "Add it"'
	expect 'deny: *--draft*' 'gh pr create --title "Add it"'
	# A --draft in the body is prose, not the flag.
	expect 'deny: *--draft*' 'gh pr create --title "Add it" --body "Mention --draft here"'
	expect 'deny: *' 'gh pr ready 12'
	expect 'deny: *' 'gh pr merge 12'
}

@test "readonly and blocked deny the shell and the file tools, readonly keeps the reading tools" {
	local tool
	policy_conf 'profile Personal' 'default-policy readonly'
	for tool in Bash PowerShell Edit Write MultiEdit NotebookEdit; do
		expect 'deny: *, readonly)*' ls "$tool"
	done
	expect allow '' Read
	expect allow '' Grep
	policy_conf 'profile Personal' 'default-policy blocked'
	for tool in Bash Edit; do
		expect 'deny: *, blocked)*' ls "$tool"
	done
}

@test "the level of a repository: the last matching line, several patterns, unknown levels, defaults" {
	# The last matching line wins, autonomous lines included, over the default.
	policy_conf 'profile Personal' 'default-policy readonly' 'policy branch github.com/myuser/*' 'autonomous github.com/MyUser/MyProject'
	fake_gh green
	expect allow 'gh pr merge 12'
	# A later, less trusting line wins.
	policy_conf 'profile Personal' 'policy autonomous github.com/myuser/*' 'policy readonly github.com/myuser/myproject'
	expect 'deny: *readonly)*' ls
	policy_conf 'profile Personal' 'default-policy readonly' 'policy branch github.com/other/* github.com/myuser/myproject'
	expect allow ls
	policy_conf 'profile Personal' 'default-policy readonly' 'policy autonomus github.com/myuser/*'
	expect 'deny: *readonly)*' ls
	# A default-policy that is no level fails closed.
	policy_conf 'profile Personal' 'default-policy autonomus'
	expect 'deny: *readonly)*' ls Bash "$OUTSIDE"
	# No default-policy line: branch, also outside any repository.
	policy_conf 'profile Personal'
	expect 'deny: *(no origin, branch)*' 'gh pr merge 12' Bash "$OUTSIDE"
	# Profiles off.
	policy_conf
	expect allow 'git push --force'
}

@test "ai-ownership-guard.sh: blocked repositories and unattended runs" {
	local base=('profile Personal' 'default-owner Personal' 'unattended on')
	policy_conf "${base[@]}" 'policy blocked github.com/myuser/*'
	expect 'block: *is blocked*' '' Bash "$FEATURE" "$GUARD" UserPromptSubmit
	policy_conf "${base[@]}" 'policy draft github.com/myuser/*'
	expect allow '' Bash "$FEATURE" "$GUARD" UserPromptSubmit
	expect 'block: *unattended runs need*' '' Bash "$FEATURE" "$GUARD" UserPromptSubmit 1
	policy_conf "${base[@]}" 'default-policy readonly'
	expect 'block: *unattended runs need*' '' Bash "$FEATURE" "$GUARD" UserPromptSubmit on
	policy_conf "${base[@]}"
	expect allow '' Bash "$FEATURE" "$GUARD" UserPromptSubmit true
	policy_conf "${base[@]}" 'autonomous github.com/myuser/myproject'
	expect allow '' Bash "$FEATURE" "$GUARD" UserPromptSubmit yes
	policy_conf 'profile Personal' 'default-owner Personal' 'unattended off'
	expect 'block: *unattended runs are off*' '' Bash "$FEATURE" "$GUARD" UserPromptSubmit 1
}

@test "ai-ownership-guard.sh: every tool call in a blocked repository, another profile's repository at any level" {
	policy_conf 'profile Personal' 'default-owner Personal' 'policy blocked github.com/myuser/myproject'
	expect 'deny: *is blocked*' '' Read "$FEATURE" "$GUARD" PreToolUse
	policy_conf 'profile Personal' 'default-owner Personal' 'owns Work github.com/myuser/*' 'autonomous github.com/myuser/myproject'
	expect 'block: *belongs to the Work AI profile*' '' Bash "$FEATURE" "$GUARD" UserPromptSubmit
}
