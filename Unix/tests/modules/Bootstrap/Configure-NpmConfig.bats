#!/usr/bin/env bats
# Configure-NpmConfig with an npmrc and npm.conf in the test folder (HOME and the backup sink point
# there too) and the token fed through FOUNDATION_TTY: configured registries change nothing and
# ask nothing, a missing or empty token line or scope line asks once and writes every registry
# that needs it, other lines keep their place, the old file is backed up first with its
# credentials redacted, --override rewrites, --dry-run asks and writes nothing, and the token
# reaches no output.

load ../../helpers

setup() {
	setup_foundation
	copy_fixture_config
	export HOME=$BATS_TEST_TMPDIR/home
	export FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/backups
	mkdir -p "$HOME"
	target=$HOME/.npmrc
	printf '%s\n' "npmrc $target" "registry https://npm.pkg.github.com/" >"$FOUNDATION_CONFIG_DIR/npm.conf"
	answers=$BATS_TEST_TMPDIR/answers
	printf 'ghp_Secret&1\n' >"$answers"
	export FOUNDATION_TTY=$answers
	cmd=$UNIX_DIR/modules/Bootstrap/bin/Configure-NpmConfig
}

@test "a missing npmrc is written with the token and owner-only permissions, no backup" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(cat "$target")" = '//npm.pkg.github.com/:_authToken=ghp_Secret&1' ]
	[ "$(stat -f %Lp "$target" 2>/dev/null || stat -c %a "$target")" = 600 ]
	[ ! -e "$FOUNDATION_BACKUP_ROOT" ]
	[[ $output != *ghp_Secret* ]]
}

@test "other lines keep their place, a stale token is replaced where it stands, a duplicate dropped" {
	printf '%s\n' 'color=false' '//npm.pkg.github.com/:_authToken = ' 'save-exact=true' '//npm.pkg.github.com/:_authToken=older' >"$target"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(cat "$target")" = "$(printf '%s\n' 'color=false' '//npm.pkg.github.com/:_authToken=ghp_Secret&1' 'save-exact=true')" ]
}

@test "the backup keeps every setting but no credential: tokens, _auth and _password are redacted" {
	printf '%s\n' 'color=false' '//npm.pkg.github.com/:_authToken=old-token' '//registry.example.invalid/:_auth = b2xkLWF1dGg=' '//other.example.invalid/:_password=old-password' >"$target"
	export TMPDIR=$BATS_TEST_TMPDIR/tmp
	mkdir -p "$TMPDIR"
	run "${BASH:-bash}" "$cmd" --override
	[ "$status" -eq 0 ]
	backup=$(find "$FOUNDATION_BACKUP_ROOT/System/NpmConfig" -type f -name .npmrc)
	[ "$(cat "$backup")" = "$(printf '%s\n' 'color=false' '//npm.pkg.github.com/:_authToken=<redacted>' '//registry.example.invalid/:_auth=<redacted>' '//other.example.invalid/:_password=<redacted>')" ]
	! grep -rqE 'old-token|b2xkLWF1dGg=|old-password|ghp_Secret' "$FOUNDATION_BACKUP_ROOT" || false
	[ -z "$(ls -A "$TMPDIR")" ]
}

@test "a scope adds its registry line, and the overlay's line of a URL replaces the base one" {
	printf '%s\n' "registry https://npm.pkg.github.com @my-org" >"$FOUNDATION_CONFIG_DIR/npm.local.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(cat "$target")" = "$(printf '%s\n' '//npm.pkg.github.com/:_authToken=ghp_Secret&1' '@my-org:registry=https://npm.pkg.github.com/')" ]
	[[ $output == *"for @my-org written"* ]]
}

@test "configured registries change nothing and ask nothing" {
	printf '%s\n' "registry https://npm.pkg.github.com/ @my-org" "registry https://registry.example.invalid/npm/" >>"$FOUNDATION_CONFIG_DIR/npm.conf"
	printf '%s\n' '//npm.pkg.github.com/:_authToken=kept' '@my-org:registry=https://npm.pkg.github.com/' '//registry.example.invalid/npm/:_authToken=kept' >"$target"
	before=$(cat "$target")
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/no-tty run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"already configured => $target"* ]]
	[ "$(cat "$target")" = "$before" ]
	[ ! -e "$FOUNDATION_BACKUP_ROOT" ]
}

@test "only the registries that need it are written, with one token asked once" {
	printf '%s\n' "registry https://registry.example.invalid/npm/" "registry https://other.example.invalid/" >>"$FOUNDATION_CONFIG_DIR/npm.conf"
	printf '%s\n' '//registry.example.invalid/npm/:_authToken=kept' >"$target"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(grep -c 'Enter GitHub' <<<"$output")" -eq 1 ]
	grep -qxF '//registry.example.invalid/npm/:_authToken=kept' "$target"
	grep -qxF '//npm.pkg.github.com/:_authToken=ghp_Secret&1' "$target"
	grep -qxF '//other.example.invalid/:_authToken=ghp_Secret&1' "$target"
}

@test "--override rewrites a configured npmrc, empty answers are asked again" {
	printf '%s\n' '//npm.pkg.github.com/:_authToken=kept' >"$target"
	printf '\n  \nnew-token\n' >"$answers"
	run "${BASH:-bash}" "$cmd" -Override
	[ "$status" -eq 0 ]
	[[ $output == *"cannot be empty"* ]]
	[ "$(cat "$target")" = '//npm.pkg.github.com/:_authToken=new-token' ]
}

@test "--dry-run asks nothing and writes nothing" {
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/no-tty run "${BASH:-bash}" "$cmd" --dry-run
	[ "$status" -eq 0 ]
	[[ $output == *"ask for the GitHub token, write [https://npm.pkg.github.com/] into $target"* ]]
	[ ! -e "$target" ]
}

@test "without registry lines nothing is asked or written" {
	printf '%s\n' "npmrc $target" >"$FOUNDATION_CONFIG_DIR/npm.conf"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/no-tty run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -e "$target" ]
}

@test "a relative npmrc starts at the repository root, not the current folder" {
	export DOTFILES_ROOT=$BATS_TEST_TMPDIR/repo
	mkdir -p "$DOTFILES_ROOT" "$BATS_TEST_TMPDIR/elsewhere"
	printf '%s\n' "npmrc out/.npmrc" "registry https://npm.pkg.github.com/" >"$FOUNDATION_CONFIG_DIR/npm.conf"
	cd "$BATS_TEST_TMPDIR/elsewhere"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	grep -qF '_authToken=ghp_Secret&1' "$DOTFILES_ROOT/out/.npmrc"
	[ ! -e "$BATS_TEST_TMPDIR/elsewhere/out" ]
}

@test "no terminal, no answer, a failed backup and an unknown argument write nothing" {
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/no-tty run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[ ! -e "$target" ]
	: >"$answers"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[ ! -e "$target" ]
	run "${BASH:-bash}" "$cmd" --bogus
	[ "$status" -ne 0 ]
	printf 'ghp_Secret&1\n' >"$answers"
	printf '%s\n' 'color=false' >"$target"
	: >"$BATS_TEST_TMPDIR/not-a-folder"
	FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/not-a-folder run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[ "$(cat "$target")" = 'color=false' ]
}

@test "--backup-root puts the backup of the old file under that folder" {
	printf '%s\n' 'color=false' >"$target"
	run "${BASH:-bash}" "$cmd" -BackupRoot "$BATS_TEST_TMPDIR/elsewhere"
	[ "$status" -eq 0 ]
	grep -rqF 'color=false' "$BATS_TEST_TMPDIR/elsewhere/System/NpmConfig"
	[ ! -d "$FOUNDATION_BACKUP_ROOT/System/NpmConfig" ]
}

@test "a token with whitespace (a pasted command) is asked again" {
	printf 'Configure-NuGetConfig --override\nghp_Secret&1\n' >"$answers"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"no spaces"* ]]
	[ "$(cat "$target")" = '//npm.pkg.github.com/:_authToken=ghp_Secret&1' ]
}
