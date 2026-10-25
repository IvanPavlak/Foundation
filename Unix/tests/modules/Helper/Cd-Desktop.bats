#!/usr/bin/env bats
# Cd-Desktop, the shell function of Unix/modules/Helper/functions.sh: sourced into bash and zsh, it
# moves the shell to ~/Desktop, and fails without moving when there is none.

load ../../helpers

setup() {
	setup_foundation
	export HOME=$BATS_TEST_TMPDIR/home
	mkdir -p "$HOME/Desktop"
	functions=$UNIX_DIR/modules/Helper/functions.sh
}

@test "bash: Cd-Desktop moves the shell to ~/Desktop" {
	run "${BASH:-bash}" -c '. "$1"; cd /; Cd-Desktop && pwd -P' _ "$functions"
	[ "$status" -eq 0 ]
	[ "$output" = "$(cd "$HOME/Desktop" && pwd -P)" ]
}

@test "zsh: Cd-Desktop moves the shell to ~/Desktop" {
	command -v zsh >/dev/null 2>&1 || skip "zsh is not installed"
	run zsh -f -c '. "$1"; cd /; Cd-Desktop && pwd -P' _ "$functions"
	[ "$status" -eq 0 ]
	[ "$output" = "$(cd "$HOME/Desktop" && pwd -P)" ]
}

@test "without a Desktop folder it fails and the shell stays where it was" {
	rmdir "$HOME/Desktop"
	run "${BASH:-bash}" -c '. "$1"; cd /; Cd-Desktop; echo "status=$? pwd=$PWD"' _ "$functions"
	[[ $output == *"status=1 pwd=/"* ]]
}
