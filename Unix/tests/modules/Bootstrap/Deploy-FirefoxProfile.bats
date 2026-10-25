#!/usr/bin/env bats
# Deploy-FirefoxProfile against a profiles.ini under a HOME in the test folder (the repository and
# the backup sink there too): which profile is picked, --all, the backup before a real user.js is
# replaced, --check changing nothing, and the failures for a missing Firefox, ini or profile.

load ../../helpers

setup() {
	setup_foundation
	export HOME=$BATS_TEST_TMPDIR/home
	export DOTFILES_ROOT=$BATS_TEST_TMPDIR/repo
	export FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/backups
	mkdir -p "$DOTFILES_ROOT/Firefox"
	printf 'user_pref("sample", true);\n' >"$DOTFILES_ROOT/Firefox/user.js"
	source_file=$DOTFILES_ROOT/Firefox/user.js
	case $(uname -s) in
		Darwin) root="$HOME/Library/Application Support/Firefox" ;;
		*) root="$HOME/.mozilla/firefox" ;;
	esac
	mkdir -p "$root/Profiles/aaa.default" "$root/Profiles/bbb.default-release" "$root/Profiles/ccc.work"
	cmd=$UNIX_DIR/modules/Bootstrap/bin/Deploy-FirefoxProfile
}

teardown() {
	# The access-denied test locks the Firefox folder; unlock it so the test folder can go.
	chmod -R u+rwx "$HOME" 2>/dev/null || true
}

# Three profiles: aaa marked Default=1, bbb the install's default, ccc a third one.
ini_with_install() {
	cat >"$root/profiles.ini" <<'INI'
[Install4F96D1932A9F858E]
Default=Profiles/bbb.default-release
Locked=1

[Profile0]
Name=default
IsRelative=1
Path=Profiles/aaa.default
Default=1

[Profile1]
Name=default-release
IsRelative=1
Path=Profiles/bbb.default-release

[Profile2]
Name=work
IsRelative=1
Path=Profiles/ccc.work
INI
}

linked() { # PROFILE-DIR
	[ -L "$1/user.js" ] && [ "$(readlink "$1/user.js")" = "$source_file" ]
}

@test "links the install's default profile and no other" {
	ini_with_install
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	linked "$root/Profiles/bbb.default-release"
	[ ! -e "$root/Profiles/aaa.default/user.js" ]
	[ ! -e "$root/Profiles/ccc.work/user.js" ]
}

@test "without an install section the profile marked Default=1 is linked" {
	printf '[Profile0]\nPath=Profiles/ccc.work\n\n[Profile1]\nPath=Profiles/aaa.default\nDefault=1\n' >"$root/profiles.ini"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	linked "$root/Profiles/aaa.default"
	[ ! -e "$root/Profiles/ccc.work/user.js" ]
}

@test "with no default marked at all the first profile is linked" {
	printf '[Profile0]\nPath=Profiles/ccc.work\n\n[Profile1]\nPath=Profiles/aaa.default\n' >"$root/profiles.ini"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	linked "$root/Profiles/ccc.work"
	[ ! -e "$root/Profiles/aaa.default/user.js" ]
}

@test "--all links every profile, an absolute Path included" {
	mkdir -p "$BATS_TEST_TMPDIR/elsewhere/ddd.abs"
	ini_with_install
	printf '\n[Profile3]\nIsRelative=0\nPath=%s\n' "$BATS_TEST_TMPDIR/elsewhere/ddd.abs" >>"$root/profiles.ini"
	run "${BASH:-bash}" "$cmd" --all
	[ "$status" -eq 0 ]
	linked "$root/Profiles/aaa.default"
	linked "$root/Profiles/bbb.default-release"
	linked "$root/Profiles/ccc.work"
	linked "$BATS_TEST_TMPDIR/elsewhere/ddd.abs"
}

@test "a real user.js is backed up before it is replaced" {
	ini_with_install
	printf 'user_pref("mine", 1);\n' >"$root/Profiles/bbb.default-release/user.js"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	linked "$root/Profiles/bbb.default-release"
	backup=$(find "$FOUNDATION_BACKUP_ROOT/SymbolicLinks/Firefox.bbb.default-release.user.js" -name user.js)
	[ -n "$backup" ]
	[ "$(cat "$backup")" = 'user_pref("mine", 1);' ]
}

@test "a user.js that cannot be backed up is left in place" {
	ini_with_install
	printf 'user_pref("mine", 1);\n' >"$root/Profiles/bbb.default-release/user.js"
	# A file where the sink should be: the backup folder cannot be created.
	printf 'not a folder\n' >"$BATS_TEST_TMPDIR/blocked"
	FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/blocked run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[ ! -L "$root/Profiles/bbb.default-release/user.js" ]
	[ "$(cat "$root/Profiles/bbb.default-release/user.js")" = 'user_pref("mine", 1);' ]
}

@test "a link that points elsewhere is replaced without a backup" {
	ini_with_install
	ln -s "$BATS_TEST_TMPDIR/old-user.js" "$root/Profiles/bbb.default-release/user.js"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	linked "$root/Profiles/bbb.default-release"
	[ ! -e "$FOUNDATION_BACKUP_ROOT" ]
}

@test "an already linked profile is left alone" {
	ini_with_install
	ln -s "$source_file" "$root/Profiles/bbb.default-release/user.js"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	linked "$root/Profiles/bbb.default-release"
	[ ! -e "$FOUNDATION_BACKUP_ROOT" ]
}

@test "--check reports and changes nothing" {
	ini_with_install
	printf 'user_pref("mine", 1);\n' >"$root/Profiles/bbb.default-release/user.js"
	run "${BASH:-bash}" "$cmd" --check --all
	[ "$status" -eq 0 ]
	[ ! -L "$root/Profiles/bbb.default-release/user.js" ]
	[ ! -e "$root/Profiles/aaa.default/user.js" ]
	[ ! -e "$FOUNDATION_BACKUP_ROOT" ]
}

@test "a profile folder that does not exist fails, the others still link" {
	ini_with_install
	rm -rf "$root/Profiles/aaa.default"
	run "${BASH:-bash}" "$cmd" --all
	[ "$status" -eq 1 ]
	[ ! -e "$root/Profiles/aaa.default" ]
	linked "$root/Profiles/bbb.default-release"
	linked "$root/Profiles/ccc.work"
}

@test "no Firefox folder, no profiles.ini, or no profile in it is an error" {
	rm -rf "$root"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	mkdir -p "$root"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	printf '[General]\nStartWithLastProfile=1\n' >"$root/profiles.ini"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
}

@test "an unknown argument is an error and links nothing" {
	ini_with_install
	run "${BASH:-bash}" "$cmd" --bogus
	[ "$status" -ne 0 ]
	[[ $output == *"Unknown argument [--bogus]"* ]]
	[ ! -e "$root/Profiles/bbb.default-release/user.js" ]
	[ ! -L "$root/Profiles/bbb.default-release/user.js" ]
}

@test "a repository without Firefox/user.js is an error and links nothing" {
	ini_with_install
	rm "$source_file"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[ ! -e "$root/Profiles/bbb.default-release/user.js" ]
	[ ! -L "$root/Profiles/bbb.default-release/user.js" ]
}

@test "a Firefox folder the terminal may not read is an error" {
	[ "$(id -u)" -ne 0 ] || skip "root reads any folder"
	ini_with_install
	chmod 000 "$root"
	run "${BASH:-bash}" "$cmd"
	chmod 755 "$root"
	[ "$status" -ne 0 ]
	[ ! -e "$root/Profiles/bbb.default-release/user.js" ]
}
