#!/usr/bin/env bats
# GitSwitch (gsw): switches to BRANCH, or back to master/main without one.

# bats file_tags=integration
load ../../helpers
load ../../git

setup() {
	setup_foundation
	git_sandbox
	cd "$REPO"
	git switch -qc other
}

@test "switches to the named branch, and back to master without a name" {
	git switch -q master
	run "${BASH:-bash}" "$bin/GitSwitch" other
	[ "$status" -eq 0 ]
	[ "$(git branch --show-current)" = other ]
	run "${BASH:-bash}" "$bin/GitSwitch"
	[ "$status" -eq 0 ]
	[ "$(git branch --show-current)" = master ]
}

@test "an unknown branch fails and stays put" {
	run "${BASH:-bash}" "$bin/GitSwitch" no-such-branch
	[ "$status" -ne 0 ]
	[ "$(git branch --show-current)" = other ]
}

@test "the Windows -BranchName names the branch" {
	git switch -q master
	run "${BASH:-bash}" "$bin/GitSwitch" -BranchName other
	[ "$status" -eq 0 ]
	[ "$(git branch --show-current)" = other ]
}

@test "a branch that exists only on origin is refused, as on Windows" {
	git push -q origin other:remote-only 2>/dev/null
	git fetch -q origin
	run "${BASH:-bash}" "$bin/GitSwitch" remote-only
	[ "$status" -ne 0 ]
	[[ $output == *"Branch 'remote-only' does not exist!"* ]]
	[ "$(git branch --show-current)" = other ]
	! git show-ref --verify --quiet refs/heads/remote-only || false
}

@test "without a name it switches to main when there is no master" {
	git switch -q master
	git branch -qm master main
	git switch -q other
	run "${BASH:-bash}" "$bin/GitSwitch"
	[ "$status" -eq 0 ]
	[ "$(git branch --show-current)" = main ]
}

@test "without a name and with neither master nor main it fails and stays put" {
	git branch -qm master trunk
	run "${BASH:-bash}" "$bin/GitSwitch"
	[ "$status" -ne 0 ]
	[[ $output == *"Neither 'master' nor 'main' branch exists in this repository!"* ]]
	[ "$(git branch --show-current)" = other ]
}
