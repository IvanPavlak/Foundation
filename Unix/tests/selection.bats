#!/usr/bin/env bats
# The shared menu of lib/foundation.sh, the Resolve-Selection port: numbers and names (any case,
# spaces or commas), each option once, invalid items and empty answers re-prompting, MULTI 0, the
# default for Enter, the Yes/No confirmation and the numbered tree of the browser-group menu. The
# answers come through FOUNDATION_TTY as a pipe, so each prompt reads the next line; names given on
# the command line resolve the same way, flat or tree, without a menu. The terminal
# check commands ask before offering a menu follows FOUNDATION_TTY too.

load helpers

setup() { setup_foundation; }

# The terminal answers, one line per prompt. Usage: answers LINE...
answers() {
	exec 7< <(printf '%s\n' "$@")
	export FOUNDATION_TTY=/dev/fd/7
}

# Runs a menu: PICKED holds its stdout (the chosen values) joined by |, MENU its stderr (the menu
# and prompts), STATUS its exit status. Usage: menu COMMAND...
menu() {
	STATUS=0
	"$@" >"$BATS_TEST_TMPDIR/out" 2>"$BATS_TEST_TMPDIR/err" || STATUS=$?
	PICKED=$(paste -sd'|' - <"$BATS_TEST_TMPDIR/out")
	MENU=$(cat "$BATS_TEST_TMPDIR/err")
}

@test "numbers and names, separated by commas or spaces, case-insensitive, each option once" {
	answers "1,3"
	menu foundation_resolve_selection T '' 0 1 Alpha Beta Gamma
	[ "$PICKED" = "Alpha|Gamma" ]
	answers "alpha GAMMA"
	menu foundation_resolve_selection T '' 0 1 Alpha Beta Gamma
	[ "$PICKED" = "Alpha|Gamma" ]
	answers "2 2 beta"
	menu foundation_resolve_selection T '' 0 1 Alpha Beta Gamma
	[ "$PICKED" = "Beta" ]
	[[ $MENU == *" [1] Alpha"* ]]
	[[ $MENU == *"(space/comma-separated): "* ]]
}

@test "an invalid item re-prompts, naming it, then the next answer counts" {
	answers "9" "1"
	menu foundation_resolve_selection T '' 0 1 Alpha Beta Gamma
	[ "$STATUS" -eq 0 ]
	[[ $MENU == *"Invalid selection => [9]"* ]]
	[ "$PICKED" = Alpha ]
}

@test "MULTI 0 re-prompts on two items" {
	answers "1 2" "2"
	menu foundation_resolve_selection T '' 0 0 Alpha Beta Gamma
	[[ $MENU == *"Only one selection is allowed"* ]]
	[ "$PICKED" = Beta ]
}

@test "an empty answer prints nothing with ALLOW-EMPTY 1, re-prompts with 0" {
	answers ""
	menu foundation_resolve_selection T '' 1 1 Alpha Beta
	[ "$STATUS" -eq 0 ]
	[ -z "$PICKED" ]
	answers "" "2"
	menu foundation_resolve_selection T '' 0 1 Alpha Beta
	[[ $MENU == *"Empty input is not allowed"* ]]
	[ "$PICKED" = Beta ]
}

@test "FOUNDATION_SELECTION_DEFAULT: Enter picks it, the prompt shows it, a typed answer still wins" {
	answers ""
	FOUNDATION_SELECTION_DEFAULT=2 menu foundation_resolve_selection T "Pick one" 0 0 Alpha Beta Gamma
	[[ $MENU == *"Pick one (default: Beta): "* ]]
	[ "$PICKED" = Beta ]
	answers ""
	FOUNDATION_SELECTION_DEFAULT=gamma menu foundation_resolve_selection T '' 0 0 Alpha Beta Gamma
	[ "$PICKED" = Gamma ]
	answers "1"
	FOUNDATION_SELECTION_DEFAULT=2 menu foundation_resolve_selection T '' 0 0 Alpha Beta Gamma
	[ "$PICKED" = Alpha ]
}

@test "without a terminal the menu fails and prints nothing" {
	export FOUNDATION_TTY=$BATS_TEST_TMPDIR/no-terminal
	menu foundation_resolve_selection T '' 1 1 Alpha
	[ "$STATUS" -eq 1 ]
	[ -z "$PICKED" ]
	[[ $MENU == *"No selection possible without a terminal"* ]]
}

@test "foundation_confirm: Yes succeeds, No and Enter fail, Enter is No, and nothing reaches stdout" {
	for reply in y YES 1; do
		answers "$reply"
		menu foundation_confirm T "Sure?"
		[ "$STATUS" -eq 0 ]
		[ -z "$PICKED" ]
	done
	for reply in no 2 ''; do
		answers "$reply"
		menu foundation_confirm T "Sure?"
		[ "$STATUS" -eq 1 ]
	done
	[[ $MENU == *"Sure? (default: No): "* ]]
}

@test "tree: numbered by position, indented per level, picked by index path, name, path or value" {
	nodes=(AI $'AI.Claude\tClaude' GitHub GitHub.Personal GitHub.Personal.Repo GitHub.Work)
	answers "2.1.1 work 1.1 github"
	menu foundation_resolve_tree_selection T '' 0 1 "${nodes[@]}"
	[ "$STATUS" -eq 0 ]
	[[ $MENU == *" [1] AI"* ]]
	[[ $MENU == *"   [1.1] Claude"* ]]
	[[ $MENU == *"     [2.1.1] Repo"* ]]
	[[ $MENU == *"   [2.2] Work"* ]]
	[ "$PICKED" = "GitHub.Personal.Repo|GitHub.Work|Claude|GitHub" ]
	answers "1.2" "GitHub.Personal"
	menu foundation_resolve_tree_selection T '' 0 0 "${nodes[@]}"
	[[ $MENU == *"Invalid selection => [1.2]"* ]]
	[ "$PICKED" = GitHub.Personal ]
}

@test "browser_menu_nodes: sections depth first with their named URLs, nested sections under their parent" {
	run browser_menu_nodes
	[ "$status" -eq 0 ]
	[ "$(printf '%s\n' "$output" | paste -sd'|' -)" = $'Search|Docs|Docs.Reference\tReference|Code|Code.Personal|Code.Personal.SampleRepository\tSampleRepository|Code.Work' ]
}

@test "the terminal check follows FOUNDATION_TTY: an answers file is a terminal, a missing one is not" {
	run foundation_has_terminal
	[ "$status" -ne 0 ]
	printf 'x\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run foundation_has_terminal
	[ "$status" -eq 0 ]
}

@test "given names resolve as menu answers do: a number, a name in any case, the menu's own entries; the rest as given" {
	run foundation_resolve_items 2 alpha none Nope 9 0 -- Alpha Beta All None
	[ "$status" -eq 0 ]
	[ "$(printf '%s\n' "$output" | paste -sd'|' -)" = "Beta|Alpha|None|Nope|9|0" ]
	run foundation_resolve_items -- Alpha
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "given names resolve against the tree menu: an index path, a path, a name or a value" {
	nodes=(AI AI.Claude GitHub GitHub.Personal $'GitHub.Personal.Repo\tRepo')
	run foundation_resolve_tree_items 2.1 ai.claude personal 2.1.1 Nope -- "${nodes[@]}"
	[ "$status" -eq 0 ]
	[ "$(printf '%s\n' "$output" | paste -sd'|' -)" = "GitHub.Personal|AI.Claude|GitHub.Personal|Repo|Nope" ]
}

@test "a number or an index path is a menu number, a name with digits is not" {
	run foundation_has_number Server 2
	[ "$status" -eq 0 ]
	run foundation_has_number 1.2
	[ "$status" -eq 0 ]
	run foundation_has_number Server2 1.a ''
	[ "$status" -eq 1 ]
}
