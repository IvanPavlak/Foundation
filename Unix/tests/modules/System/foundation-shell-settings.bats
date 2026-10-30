#!/usr/bin/env bats
# foundation-shell-settings: the prompt theme, the shell.conf line-editing settings and the apps.conf
# tokens a new interactive shell applies, one KEY VALUE line each, the key lines as finished
# bindkey lines; a setting without a valid line is left out.

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
	printf 'history-size 4096\nedit-mode emacs\n@Laptop history-size 7\n' >"$FOUNDATION_CONFIG_DIR/shell.conf"
	printf 'history-size 32767\nhistory-file ~/hist\nedit-mode VI\n' >"$FOUNDATION_CONFIG_DIR/shell.local.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "${lines[1]}" = "history-size 32767" ]
	[ "${lines[2]}" = "history-file $HOME/hist" ]
	[ "${lines[3]}" = "edit-mode vi" ]
}

@test "a value its kind does not take is left out, as is a line kind shell.conf does not know" {
	printf 'history-size lots\nedit-mode emacsy\nlist-lines 5\nhistory-no-duplicates maybe\nprediction-view grid\nhistory-file ~/hist\n' >"$FOUNDATION_CONFIG_DIR/shell.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output != *history-size* ]]
	[[ $output != *edit-mode* ]]
	[[ $output != *list-lines* ]]
	[[ $output != *history-no-duplicates* ]]
	[[ $output != *prediction-view* ]]
	[[ $output == *"history-file $HOME/hist"* ]]
}

@test "a shell.conf with comments only, as the base ships, prints no line-editing setting" {
	printf '# nothing set\n' >"$FOUNDATION_CONFIG_DIR/shell.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$output" = "prompt-theme $DOTFILES_ROOT/Oh-My-Posh/WinuX_Test.omp.json" ]
}

@test "the switches, prediction kinds and list colours are printed normalized, in any case" {
	printf 'edit-mode Windows\nhistory-no-duplicates ON\nhistory-save-style Incrementally\ncompletion-ignore-case On\nprediction-source History\nprediction-view LIST\nprediction-list-marker ->\ncolor-list-prediction #1E90FF\ncolor-emphasis Red\ncolor-list-prediction-selected orange\n' >"$FOUNDATION_CONFIG_DIR/shell.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *$'edit-mode windows\nhistory-no-duplicates on\nhistory-save-style incrementally\ncompletion-ignore-case on\nprediction-source history\nprediction-view list\nprediction-list-marker ->\ncolor-list-prediction #1E90FF\ncolor-emphasis red'* ]]
	[[ $output != *color-list-prediction-selected* ]]
}

@test "key lines become bindkey lines over the windows-mode keys; the overlay wins per key, - drops one" {
	printf 'edit-mode windows\nkey UpArrow PreviousHistory\nkey Ctrl+r ReverseSearchHistory\n' >"$FOUNDATION_CONFIG_DIR/shell.conf"
	printf 'key UpArrow HistorySearchBackward\nkey Home -\nkey F2 my-widget\nkey Tab NoSuchFunction\n' >"$FOUNDATION_CONFIG_DIR/shell.local.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"bindkey ^[[A history-beginning-search-backward"* ]]
	[[ $output == *"bindkey ^[OA history-beginning-search-backward"* ]]
	[[ $output != *up-line-or-history* ]]
	[[ $output == *"bindkey ^R history-incremental-search-backward"* ]]
	[[ $output == *"bindkey ^[OQ my-widget"* ]]
	[[ $output == *"bindkey ^[[3~ delete-char"* ]]
	[[ $output != *beginning-of-line* ]]
	# Tab NoSuchFunction is skipped, so Tab keeps the windows layer's cycling.
	[[ $output == *"bindkey ^I menu-complete"* ]]
}

@test "without edit-mode windows only the key lines are bound" {
	printf 'edit-mode emacs\nkey DownArrow HistorySearchForward\n' >"$FOUNDATION_CONFIG_DIR/shell.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(grep -c '^bindkey ' <<<"$output")" -eq 2 ]
	[[ $output == *"bindkey ^[[B history-beginning-search-forward"* ]]
}

@test "every apps.conf token is an app line, for the Open-<TOKEN> aliases" {
	printf 'app Slack com.tinyspeck.slackmacgap\napp DBeaver org.jkiss.dbeaver.core.product\n' >"$FOUNDATION_CONFIG_DIR/apps.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *$'app Slack\napp DBeaver'* ]]
}

@test "the list-color lines of theme.conf become one eza-colors line; none without them" {
	printf 'list-color user #FFA500\n' >"$FOUNDATION_CONFIG_DIR/theme.conf"
	printf 'list-color date red\n' >"$FOUNDATION_CONFIG_DIR/theme.local.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "${lines[1]}" = 'eza-colors uu=38;2;255;165;0:da=31' ]
	printf 'step SetWallpaper on\n' >"$FOUNDATION_CONFIG_DIR/theme.conf"
	rm "$FOUNDATION_CONFIG_DIR/theme.local.conf"
	run "${BASH:-bash}" "$cmd"
	[[ $output != *eza-colors* ]]
}
