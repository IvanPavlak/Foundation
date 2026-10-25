#!/usr/bin/env bats
# Initialize-Configuration on a fixture copy, a throwaway HOME (no global git identity, a chezmoi
# config the test writes) and a scutil stand-in: a fresh clone gets the git identity, this Mac's
# host line and its machine type's dev root from the environment without a terminal or from the
# prompts; what is set is neither asked nor written; --force replaces after a backup and writes
# nothing when the backup fails; an unknown machine type fails; --dry-run writes nothing.

load ../../helpers

setup() {
	setup_foundation
	copy_fixture_config
	export HOME=$BATS_TEST_TMPDIR/home XDG_CONFIG_HOME=$BATS_TEST_TMPDIR/home/.config
	export FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/backups
	mkdir -p "$XDG_CONFIG_HOME/chezmoi"
	printf '[data]\n    machineType = "Work"\n' >"$XDG_CONFIG_HOME/chezmoi/chezmoi.toml"
	stub_tool scutil "[ \"\$1\" = --get ] && echo My-Mac; exit 0"
	[ "$(command -v scutil)" = "$BATS_TEST_TMPDIR/tools/scutil" ]
	parent=$(dirname "$DOTFILES_ROOT")
	machines=$FOUNDATION_CONFIG_DIR/machines.local.conf
	identity=$FOUNDATION_CONFIG_DIR/git.local.conf
	cmd=$UNIX_DIR/modules/Bootstrap/bin/Initialize-Configuration
}

# Answers for a run that reads the terminal more than once: every prompt reopens FOUNDATION_TTY, and
# a reopened /dev/fd pipe goes on where the last read stopped, where a file starts over.
piped_answers() {
	exec 7< <(printf '%s\n' "$@")
	export FOUNDATION_TTY=/dev/fd/7
}

@test "a fresh clone without a terminal: identity from the environment, chezmoi's type, the clone's parent as dev root" {
	FOUNDATION_GIT_NAME="Jane Doe" FOUNDATION_GIT_EMAIL=jane@example.invalid run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(grep -v '^#' "$identity" | paste -sd'|' -)" = "name Jane Doe|email jane@example.invalid" ]
	grep -qx 'host My-Mac Work' "$machines"
	grep -qx "@Work dev-root $parent" "$machines"
	# The new lines are what the readers resolve.
	[ "$(foundation_machine_type)" = Work ]
	[ "$(FOUNDATION_MACHINE_TYPE=Work foundation_dev_root)" = "$parent" ]
}

@test "the prompts take the answers, Enter keeps the default" {
	mkdir -p "$BATS_TEST_TMPDIR/dev"
	piped_answers "Jane Doe" "jane@example.invalid" "New-Mac" "laptop" "$BATS_TEST_TMPDIR/dev"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	grep -qx 'name Jane Doe' "$identity"
	grep -qx 'host New-Mac Laptop' "$machines"
	grep -qx "@Laptop dev-root $BATS_TEST_TMPDIR/dev" "$machines"
	[[ $output == *"renames this Mac from My-Mac to New-Mac"* ]]
	piped_answers "" "" "" "" ""
	rm -f "$identity" "$machines"
	run "${BASH:-bash}" "$cmd" --force
	grep -qx 'host My-Mac Work' "$machines"
	! grep -q '^name' "$identity" 2>/dev/null || false
}

@test "what is set is neither asked nor written" {
	printf 'name Jane Doe\nemail jane@example.invalid\n' >"$identity"
	printf 'host my-mac Laptop\n@Laptop dev-root ~/Projects\n' >"$machines"
	cp "$machines" "$BATS_TEST_TMPDIR/before"
	piped_answers "WRONG" "WRONG" "WRONG" "WRONG" "WRONG"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"already configured => My-Mac (Laptop)"* ]]
	[[ $output == *"Dev root already set => ~/Projects"* ]]
	cmp -s "$machines" "$BATS_TEST_TMPDIR/before"
	! grep -q WRONG "$identity" || false
	[ ! -d "$FOUNDATION_BACKUP_ROOT" ]
}

@test "--force replaces the lines after backing the overlay up" {
	printf 'host My-Mac Laptop\n@Work dev-root ~/Old\nsmall-display Laptop\n' >"$machines"
	run "${BASH:-bash}" "$cmd" --force --machine-type Work --dev-root "$BATS_TEST_TMPDIR" --git-name "Jane Doe" --git-email jane@example.invalid
	[ "$status" -eq 0 ]
	[ "$(grep -c '^host My-Mac' "$machines")" -eq 1 ]
	grep -qx 'host My-Mac Work' "$machines"
	! grep -q 'dev-root ~/Old' "$machines" || false
	grep -qx 'small-display Laptop' "$machines"
	find "$FOUNDATION_BACKUP_ROOT/Config" -name machines.local.conf | grep -q .
}

@test "--force writes nothing when the overlays cannot be backed up" {
	printf 'name Old Name\nemail old@example.invalid\n' >"$identity"
	printf 'host My-Mac Laptop\n@Laptop dev-root ~/Old\n' >"$machines"
	cp "$identity" "$BATS_TEST_TMPDIR/identity-before"
	cp "$machines" "$BATS_TEST_TMPDIR/machines-before"
	# A regular file where the sink's folder goes: the backup cannot be created.
	: >"$BATS_TEST_TMPDIR/not-a-folder"
	FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/not-a-folder run "${BASH:-bash}" "$cmd" --force --machine-type Work --dev-root "$BATS_TEST_TMPDIR" --git-name "Jane Doe" --git-email jane@example.invalid
	[ "$status" -ne 0 ]
	cmp -s "$identity" "$BATS_TEST_TMPDIR/identity-before"
	cmp -s "$machines" "$BATS_TEST_TMPDIR/machines-before"
}

@test "an unknown machine type fails and maps nothing" {
	run "${BASH:-bash}" "$cmd" --machine-type Server --git-name x --git-email y
	[ "$status" -ne 0 ]
	[[ $output == *"Unknown machine type [Server]"* ]]
	! grep -q '^host' "$machines" 2>/dev/null || false
}

@test "--dry-run asks nothing and writes nothing" {
	piped_answers "Jane Doe" "jane@example.invalid"
	run "${BASH:-bash}" "$cmd" --dry-run
	[ "$status" -eq 0 ]
	[[ $output == *"Would ask for the git name"* ]]
	[[ $output == *"Would write to "*"machines.local.conf => host My-Mac Work"* ]]
	[ ! -e "$identity" ]
	[ ! -e "$machines" ]
}

@test "the Windows -Owner defaults the git name, -DevPath is the dev root, -WhatIf the dry run" {
	mkdir -p "$BATS_TEST_TMPDIR/dev"
	run "${BASH:-bash}" "$cmd" -WhatIf -Owner jdoe
	[ "$status" -eq 0 ]
	[ ! -e "$identity" ]
	[ ! -e "$machines" ]
	run "${BASH:-bash}" "$cmd" -Owner jdoe -DevPath "$BATS_TEST_TMPDIR/dev"
	[ "$status" -eq 0 ]
	grep -qx 'name jdoe' "$identity"
	grep -qx "@Work dev-root $BATS_TEST_TMPDIR/dev" "$machines"
	# A given git name wins over the owner.
	rm -f "$identity"
	run "${BASH:-bash}" "$cmd" --owner jdoe --git-name "Jane Doe"
	grep -qx 'name Jane Doe' "$identity"
}
