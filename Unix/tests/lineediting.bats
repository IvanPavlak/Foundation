#!/usr/bin/env bats
# lib/lineediting.sh: the PSReadLine names of shell.conf translated for zle - the scalar values,
# the key names, the function names, the merged key bindings over the Windows-mode layer - and
# the problems Test-ConfigurationSchema reports.

load helpers

setup() {
	setup_foundation
	foundation_load lineediting
}

@test "a scalar value is normalized, in any case; a value its kind does not take fails" {
	[ "$(lineediting_setting edit-mode WINDOWS)" = windows ]
	[ "$(lineediting_setting history-no-duplicates Off)" = off ]
	[ "$(lineediting_setting prediction-view List)" = list ]
	[ "$(lineediting_setting history-size 32767)" = 32767 ]
	run lineediting_setting history-size 0
	[ "$status" -eq 1 ]
	run lineediting_setting edit-mode windowsy
	[ "$status" -eq 1 ]
	run lineediting_setting prediction-source plugin
	[ "$status" -eq 1 ]
	run lineediting_setting list-lines 5
	[ "$status" -eq 1 ]
	[ "$(lineediting_setting history-save-style Incrementally)" = incrementally ]
	[ "$(lineediting_setting completion-ignore-case ON)" = on ]
	[ "$(lineediting_setting prediction-list-marker '->')" = '->' ]
	run lineediting_setting history-save-style always
	[ "$status" -eq 1 ]
}

@test "a list colour is one of the eight names, 0-255 or #RRGGBB" {
	[ "$(lineediting_setting color-list-prediction Yellow)" = yellow ]
	[ "$(lineediting_setting color-emphasis 208)" = 208 ]
	[ "$(lineediting_setting color-list-prediction-selected '#1E90FF')" = '#1E90FF' ]
	for bad in orange 256 '#12345' dodgerblue; do
		run lineediting_setting color-list-prediction "$bad"
		[ "$status" -eq 1 ]
	done
}

@test "a key name gives every sequence a terminal sends for it; a ^ sequence passes as it is" {
	[ "$(lineediting_key_sequences uparrow)" = $'^[[A\n^[OA' ]
	[ "$(lineediting_key_sequences Shift+Tab)" = '^[[Z' ]
	[ "$(lineediting_key_sequences Ctrl+Spacebar)" = '^@' ]
	[ "$(lineediting_key_sequences Ctrl+r)" = '^R' ]
	[ "$(lineediting_key_sequences Alt+b)" = '^[b' ]
	[ "$(lineediting_key_sequences Ctrl+LeftArrow)" = '^[[1;5D' ]
	[ "$(lineediting_key_sequences Shift+UpArrow)" = '^[[1;2A' ]
	[ "$(lineediting_key_sequences F2)" = '^[OQ' ]
	[ "$(lineediting_key_sequences '^X^E')" = '^X^E' ]
	run lineediting_key_sequences Meta+UpArrow
	[ "$status" -eq 1 ]
	run lineediting_key_sequences NoSuchKey
	[ "$status" -eq 1 ]
}

@test "a PSReadLine function maps to its widget, a zle widget name passes, anything else fails" {
	[ "$(lineediting_widget historysearchbackward)" = history-beginning-search-backward ]
	[ "$(lineediting_widget MenuComplete)" = menu-select ]
	[ "$(lineediting_widget TabCompleteNext)" = menu-complete ]
	[ "$(lineediting_widget Complete)" = expand-or-complete ]
	[ "$(lineediting_widget my-widget)" = my-widget ]
	[ "$(lineediting_widget .accept-line)" = .accept-line ]
	run lineediting_widget NoSuchFunction
	[ "$status" -eq 1 ]
	run lineediting_widget 'two words'
	[ "$status" -eq 1 ]
}

@test "bindings: the windows layer under the lines, a later line wins per sequence, - drops, bad lines skipped" {
	run lineediting_bindings windows <<<$'UpArrow PreviousHistory\nUpArrow HistorySearchBackward\n^[OA up-line-or-history\nHome -\nBogus AcceptLine\nTab NoSuchFunction'
	[ "$status" -eq 0 ]
	[[ $output == *"^[[A history-beginning-search-backward"* ]]
	[[ $output == *"^[OA up-line-or-history"* ]]
	[[ $output == *"^[[1;5C forward-word"* ]]
	[[ $output == *"^I menu-complete"* ]]
	[[ $output == *"^[[Z reverse-menu-complete"* ]]
	[[ $output != *beginning-of-line* ]]
	[[ $output != *PreviousHistory* ]]
	[[ $output != *Bogus* ]]
}

@test "bindings: no windows layer for emacs or vi, and nothing at all without lines" {
	run lineediting_bindings emacs </dev/null
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	run lineediting_bindings vi <<<'Ctrl+Spacebar MenuComplete'
	[ "$output" = '^@ menu-select' ]
}

@test "problems: each bad line is named once, a clean file gives none" {
	run lineediting_problems <<<$'key UpArrow\nkey Foo Undo\nkey Tab NotReal\nkey Home -\nedit-mode emacsy\nhistory-size 0\nlist-lines 5\nhistory-no-duplicates on'
	[ "$status" -eq 0 ]
	[ "${#lines[@]}" -eq 6 ]
	[[ $output == *"key [UpArrow] is not KEY FUNCTION"* ]]
	[[ $output == *"key Foo: unknown key name"* ]]
	[[ $output == *"key Tab: unknown function NotReal"* ]]
	[[ $output == *"edit-mode: [emacsy]"* ]]
	[[ $output == *"history-size: [0]"* ]]
	[[ $output == *"unknown line kind list-lines"* ]]
	run lineediting_problems <<<$'edit-mode windows\nkey UpArrow HistorySearchBackward\nprediction-view list\nhistory-save-style incrementally\ncompletion-ignore-case on\nprediction-list-marker ->\ncolor-emphasis red'
	[ -z "$output" ]
}

@test "list-color: friendly names and eza keys, colours as SGR codes, a later line wins per key" {
	[ "$(lineediting_list_color_key User)" = uu ]
	[ "$(lineediting_list_color_key file)" = 'fi' ]
	[ "$(lineediting_list_color_key DA)" = da ]
	run lineediting_list_color_key colour
	[ "$status" -eq 1 ]
	[ "$(lineediting_sgr red)" = 31 ]
	[ "$(lineediting_sgr 208)" = '38;5;208' ]
	[ "$(lineediting_sgr '#FFA500')" = '38;2;255;165;0' ]
	run lineediting_sgr orange
	[ "$status" -eq 1 ]
	run lineediting_eza_colors <<<$'user #FFA500\ndate red\ncolour red\nsize orange\ndate 1'
	[ "$output" = 'uu=38;2;255;165;0:da=38;5;1' ]
	run lineediting_eza_colors </dev/null
	[ -z "$output" ]
}
