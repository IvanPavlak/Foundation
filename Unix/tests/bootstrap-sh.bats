#!/usr/bin/env bats
# Unix/bootstrap.sh, the bash 3.2 entry point, against stand-ins for chezmoi and xcode-select
# (first on PATH) and a throwaway home and backup sink: init, backup of the real files a link
# replaces, then apply; a dry run changes nothing; a failed backup applies nothing; its session
# log, which chezmoi apply inherits. Also the first-run helper chezmoi hands over to
# (bootstrap-first-run): --help provisions nothing.

load helpers

setup() {
	setup_foundation
	export HOME=$BATS_TEST_TMPDIR/user-home
	unset XDG_CONFIG_HOME
	export FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/backups
	mkdir -p "$HOME/.config/btop/themes" "$HOME/.config/chezmoi"
	printf 'mine\n' >"$HOME/.zshrc"
	printf 't\n' >"$HOME/.config/btop/themes/a.theme"
	ln -s /nonexistent "$HOME/.gitconfig"
	: >"$HOME/.config/chezmoi/chezmoi.toml"
	stub_tool xcode-select 'echo /Library/Developer/CommandLineTools'
	stub_tool chezmoi 'case $1 in --version) echo "chezmoi stand-in" ;; managed) printf "%s\n" .zshrc .gitconfig .config/btop/themes .ssh/config ;; esac'
	script=$UNIX_DIR/bootstrap.sh
}

@test "init, a backup of every real file a link replaces, then apply" {
	run /bin/bash "$script"
	[ "$status" -eq 0 ]
	[ "$(grep -c '^chezmoi init --source ' "$BATS_TEST_TMPDIR/tool.log")" -eq 1 ]
	[ "$(tail -1 "$BATS_TEST_TMPDIR/tool.log")" = "chezmoi apply" ]
	[ "$(cat "$FOUNDATION_BACKUP_ROOT"/SymbolicLinks/Dotfiles.zshrc/*/.zshrc)" = mine ]
	[ -f "$(echo "$FOUNDATION_BACKUP_ROOT"/SymbolicLinks/Dotfiles.config.btop.themes/*/themes/a.theme)" ]
	[ "$(ls "$FOUNDATION_BACKUP_ROOT/SymbolicLinks")" = "$(printf 'Dotfiles.config.btop.themes\nDotfiles.zshrc')" ]
	[ "$(cat "$HOME/.zshrc")" = mine ]
}

@test "a dry run runs neither init nor apply and backs up nothing" {
	run /bin/bash "$script" --dry-run
	[ "$status" -eq 0 ]
	[ "$(grep -Ec '^chezmoi (init|apply)' "$BATS_TEST_TMPDIR/tool.log")" -eq 0 ]
	grep -q '^chezmoi diff' "$BATS_TEST_TMPDIR/tool.log"
	[[ $output == *"Would back up ~/.zshrc"* ]]
	[ ! -e "$FOUNDATION_BACKUP_ROOT" ]
	rm "$HOME/.config/chezmoi/chezmoi.toml"
	rmdir "$HOME/.config/chezmoi"
	: >"$BATS_TEST_TMPDIR/tool.log"
	run /bin/bash "$script" --dry-run
	[ "$status" -eq 0 ]
	[ "$(grep -Ec '^chezmoi (init|apply|diff|managed)' "$BATS_TEST_TMPDIR/tool.log")" -eq 0 ]
}

@test "a failed backup applies nothing, and an unknown argument is refused" {
	mkdir -p "$BATS_TEST_TMPDIR/read-only"
	chmod 500 "$BATS_TEST_TMPDIR/read-only"
	FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/read-only/backups run /bin/bash "$script"
	chmod 700 "$BATS_TEST_TMPDIR/read-only"
	[ "$status" -ne 0 ]
	[ "$(grep -c '^chezmoi apply' "$BATS_TEST_TMPDIR/tool.log")" -eq 0 ]
	[ "$(cat "$HOME/.zshrc")" = mine ]
	run /bin/bash "$script" --only Packages
	[ "$status" -ne 0 ]
	[[ $output == *"Bootstrap --only"* ]]
}

@test "bootstrap-first-run --help prints its usage and provisions nothing; an unknown argument fails" {
	# A copy beside a stand-in Bootstrap (the command it hands over to), and a curl that fails:
	# should the helper act anyway, it reaches only stand-ins.
	mkdir -p "$BATS_TEST_TMPDIR/first-run"
	cp "$UNIX_DIR/modules/Bootstrap/bin/bootstrap-first-run" "$BATS_TEST_TMPDIR/first-run/"
	printf '#!/bin/sh\necho "Bootstrap $*" >>"%s/tool.log"\n' "$BATS_TEST_TMPDIR" >"$BATS_TEST_TMPDIR/first-run/Bootstrap"
	chmod +x "$BATS_TEST_TMPDIR/first-run/Bootstrap"
	stub_tool curl 'exit 1'
	for flag in --help -h; do
		run sh "$BATS_TEST_TMPDIR/first-run/bootstrap-first-run" "$flag"
		[ "$status" -eq 0 ]
		[[ $output == *"Usage: bootstrap-first-run"* ]]
	done
	run sh "$BATS_TEST_TMPDIR/first-run/bootstrap-first-run" --bogus-flag
	[ "$status" -eq 1 ]
	[ ! -e "$BATS_TEST_TMPDIR/tool.log" ]
}

@test "it opens a session log that chezmoi apply, and so the first-run hand-over, inherits" {
	unset FOUNDATION_LOGGING
	export FOUNDATION_LOG_DIR=$BATS_TEST_TMPDIR/logs
	stub_tool chezmoi 'case $1 in --version) echo "chezmoi stand-in" ;; apply) printf "%s\n" "$FOUNDATION_LOG_FILE" >"'"$BATS_TEST_TMPDIR"'/apply-log" ;; esac'
	run /bin/bash "$script"
	[ "$status" -eq 0 ]
	logs=("$FOUNDATION_LOG_DIR"/Session_*_bootstrap.sh.log)
	[ ${#logs[@]} -eq 1 ]
	[ -f "${logs[0]}" ]
	grep -q '\[TITLE\] 5 chezmoi apply' "${logs[0]}"
	grep -q '\[SUCCESS\] Dotfiles linked!' "${logs[0]}"
	[ "$(cat "$BATS_TEST_TMPDIR/apply-log")" = "${logs[0]}" ]
}
