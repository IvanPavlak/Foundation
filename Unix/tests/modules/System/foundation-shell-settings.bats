#!/usr/bin/env bats
# foundation-shell-settings: the prompt theme, the shell.conf line-editing settings and the apps.conf
# tokens a new interactive shell applies, one KEY VALUE line each; a setting without a valid line
# is left out.

load ../../helpers

setup() {
	setup_foundation
	use_empty_config
	cmd=$UNIX_DIR/modules/System/bin/foundation-shell-settings
	export FOUNDATION_MACHINE_TYPE=Work
}

@test "without shell.conf only the prompt theme is printed" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$output" = "prompt-theme $DOTFILES_ROOT/Oh-My-Posh/WinuX_Test.omp.json" ]
	run "${BASH:-bash}" "$cmd" --prompt-theme
	[ "$output" = "$DOTFILES_ROOT/Oh-My-Posh/WinuX_Test.omp.json" ]
}

@test "shell.conf settings for this machine type, the overlay winning, the history file expanded" {
	printf 'history-size 4096\nedit-mode emacs\nlist-lines 10\n@Laptop history-size 7\n' >"$FOUNDATION_CONFIG_DIR/shell.conf"
	printf 'history-size 32767\nhistory-file ~/hist\nedit-mode VI\n' >"$FOUNDATION_CONFIG_DIR/shell.local.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "${lines[1]}" = "history-size 32767" ]
	[ "${lines[2]}" = "history-file $HOME/hist" ]
	[ "${lines[3]}" = "edit-mode vi" ]
	[ "${lines[4]}" = "list-lines 10" ]
}

@test "a value that is not a number or a known edit mode is left out" {
	printf 'history-size lots\nedit-mode windows\nlist-lines 5\n' >"$FOUNDATION_CONFIG_DIR/shell.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output != *history-size* ]]
	[[ $output != *edit-mode* ]]
	[[ $output == *"list-lines 5"* ]]
}

@test "every apps.conf token is an app line, for the Open-<TOKEN> aliases" {
	printf 'app Slack com.tinyspeck.slackmacgap\napp DBeaver org.jkiss.dbeaver.core.product\n' >"$FOUNDATION_CONFIG_DIR/apps.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *$'app Slack\napp DBeaver'* ]]
}
