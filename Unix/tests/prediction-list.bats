#!/usr/bin/env bats
# Unix/shell/prediction-list.zsh, the prediction list (PSReadLine's ListView) for zsh: which history
# lines it lists for the typed text (anywhere in the line, case-insensitive, newest first, each
# once), how it draws them (header, rows, the window of 10, the colours of shell.conf), and Up and
# Down moving in it while it shows and running the key's own widget otherwise. A plain zsh sources
# the file with zle and bindkey stood in, over a history file of its own.

load helpers

setup() {
	setup_foundation
	command -v zsh >/dev/null 2>&1 || skip "zsh is not installed"
	list=$UNIX_DIR/shell/prediction-list.zsh
	hist=$BATS_TEST_TMPDIR/history
	# A plain zsh treats the file's last line as the line being edited and leaves it out of
	# $history: the last line here only pads.
	printf '%s\n' 'echo first' 'git status' 'Get-Date' 'git remote -v' 'git log --oneline -3' 'git status' 'pad' >"$hist"
}

# Sources the list into a plain zsh with its history, then runs SCRIPT; `zle WIDGET` prints
# "ran WIDGET" (`zle -N`, which the file runs when sourced, prints nothing). Usage: run_list SCRIPT
run_list() {
	run zsh -f -c '
		add-zle-hook-widget() { :; }
		bindkey() { [[ $1 == -- ]] && print -r -- "\"$2\" up-line-or-history"; :; }
		zle() { [[ $1 == -* ]] || print -r -- "ran $1"; }
		autoload() { :; }
		. "$1"
		fc -p "$2" 100 100
		COLUMNS=60 PREDISPLAY=
		eval "$3"
	' _ "$list" "$hist" "$1"
}

@test "the typed text matches anywhere in a line, in any case, newest first, each line once" {
	run_list '_foundation_prediction_find STATUS; print -rl -- $_foundation_prediction_matches; print sep; _foundation_prediction_find g; print -rl -- $_foundation_prediction_matches'
	[ "$status" -eq 0 ]
	[ "$output" = $'git status\nsep\ngit status\ngit log --oneline -3\ngit remote -v\nGet-Date' ]
}

@test "blank text, or text no line has, lists nothing" {
	run_list '_foundation_prediction_find "  "; print "blank=${#_foundation_prediction_matches}"; _foundation_prediction_find zzz; print "none=${#_foundation_prediction_matches}"'
	[ "$output" = $'blank=0\nnone=0' ]
}

@test "the list is a <n/N> header and > rows with [History], the selected row and the typed text coloured" {
	run_list 'BUFFER=git _foundation_prediction_typed=git; _foundation_prediction_find git; _foundation_prediction_selected=2; _foundation_prediction_render; print -r -- "$POSTDISPLAY"; print -rl -- $region_highlight'
	[ "$status" -eq 0 ]
	[[ ${lines[0]} == "<2/3>"*"<History(3)>" ]]
	[[ ${lines[1]} == "> git status"*"[History]" ]]
	[[ ${lines[2]} == "> git log --oneline -3"*"[History]" ]]
	[ "$(grep -c 'fg=yellow memo=foundation-prediction' <<<"$output")" -eq 3 ]
	[ "$(grep -c 'bg=238 memo=foundation-prediction' <<<"$output")" -eq 1 ]
	[ "$(grep -c 'fg=14 memo=foundation-prediction' <<<"$output")" -eq 3 ]
}

@test "every place the typed text occurs in a row is highlighted, and the marker line replaces >" {
	run zsh -f -c '
		add-zle-hook-widget() { :; }; bindkey() { :; }; zle() { :; }; autoload() { :; }
		_foundation_prediction_marker="->"
		. "$1"; fc -p "$2" 100 100; COLUMNS=60 PREDISPLAY=
		BUFFER=t _foundation_prediction_typed=t; _foundation_prediction_find T; _foundation_prediction_render
		print -r -- "$POSTDISPLAY"
		full=$BUFFER$POSTDISPLAY
		for h in $region_highlight; do [[ $h == *fg=14* ]] || continue; s=${${h%% *}#P}; e=${${h#* }%% *}; print -rn -- "[${full[s+1,e]}]"; done
	' _ "$list" "$hist"
	[[ ${lines[1]} == "-> git status"* ]]
	# git status 3, git log 1, git remote 2, Get-Date 2 (any case), echo first 1.
	[ "${lines[-1]}" = "[t][t][t][t][t][t][t][t][t]" ]
}

@test "the colour lines of shell.conf replace PSReadLine's defaults" {
	run zsh -f -c '
		add-zle-hook-widget() { :; }; bindkey() { :; }; zle() { :; }; autoload() { :; }
		_foundation_prediction_color_row="#1e90ff" _foundation_prediction_color_selected=17 _foundation_prediction_color_emphasis=red
		. "$1"; fc -p "$2" 100 100; COLUMNS=60 PREDISPLAY=
		BUFFER=git _foundation_prediction_typed=git; _foundation_prediction_find git; _foundation_prediction_selected=1; _foundation_prediction_render
		print -rl -- $region_highlight
	' _ "$list" "$hist"
	[[ $output == *"fg=#1e90ff"* ]]
	[[ $output == *"bg=17"* ]]
	[[ $output == *"fg=red"* ]]
	[[ $output != *yellow* ]]
}

@test "at most 10 rows show, and the window follows the selection" {
	{
		for i in $(seq 1 15); do printf 'echo line%s\n' "$i"; done
		echo pad
	} >"$hist"
	run_list 'BUFFER=echo _foundation_prediction_typed=echo; _foundation_prediction_find echo; _foundation_prediction_selected=12; _foundation_prediction_render; print -r -- "$POSTDISPLAY"'
	[ "${#lines[@]}" -eq 11 ]
	[[ ${lines[0]} == "<12/15>"* ]]
	[[ ${lines[1]} == "> echo line13"* ]]
	[[ ${lines[10]} == "> echo line4"* ]]
}

@test "Up and Down move in the list and the line follows; past either end it is the typed text again" {
	run_list '
		BUFFER=git _foundation_prediction_typed=git; _foundation_prediction_find git
		for d in 1 1 -1 -1 -1; do _foundation_prediction_move $d up-line-or-history; print -r -- "$_foundation_prediction_selected:$BUFFER:$CURSOR"; done'
	[ "$output" = $'1:git status:10\n2:git log --oneline -3:20\n1:git status:10\n0:git:3\n3:git remote -v:13' ]
}

@test "without a list, Up and Down run the widget the key had" {
	run_list 'BUFFER= ; _foundation_prediction_find ""; foundation-prediction-up; print -r -- "up=$_foundation_prediction_up"'
	[[ $output == *"ran up-line-or-history"* ]]
	[[ $output == *"up=up-line-or-history"* ]]
}
