#!/usr/bin/env bats
# Pattern rules of the Windows Get-WindowHandle / Test-WindowTitleMatch, foundation_ieq (-eq), and
# the Windows-style flags of foundation_normalize_args, and the time limit of foundation_timeout.

load helpers

setup() { setup_foundation; }

@test "process: plain name is an exact, case-insensitive match" {
	foundation_match_process Code code
	! foundation_match_process Code "Code Helper" || false
}

@test "process: wildcard and regex" {
	foundation_match_process 'fire*' firefox
	foundation_match_process '(firefox|chrome)' chrome
	! foundation_match_process '(firefox|chrome)' brave || false
}

@test "title: empty pattern matches anything" {
	foundation_match_title '' 'whatever'
	foundation_match_title '$null' ''
}

@test "title: plain word is a substring (regex semantics)" {
	foundation_match_title Claude 'New chat - Claude'
}

# Firefox separates page and app title with an em-dash; built from bytes so the repository's
# no-em-dash rule holds for this file.
EM=$(printf '\342\200\224')

@test "title: leading-star wildcard" {
	foundation_match_title '*YouTube*' 'YouTube - Mozilla Firefox'
	foundation_match_title '*New chat - Claude*' "New chat - Claude $EM Mozilla Firefox"
	! foundation_match_title '*YouTube*' 'Reddit' || false
}

@test "title: .NET shorthand classes are translated" {
	foundation_match_title "Google\\s*[-$EM].*" "Google $EM Mozilla Firefox"
}

@test "title: alternation regex" {
	foundation_match_title '(.*Gmail.*|.*Inbox.*)' 'Inbox (3) - Gmail'
}

@test "process: an exact name with regex metacharacters matches only itself" {
	foundation_match_process notepad++ Notepad++
	! foundation_match_process notepad++ 'notepad++ helper' || false
	! foundation_match_process notepad++ notepad || false
}

@test "title: a leading (?i) is dropped, anchors hold, a pattern ERE rejects is literal" {
	foundation_match_title '(?i)notepad' 'notes - Notepad'
	foundation_match_title '^Chrome' 'Chrome - x'
	! foundation_match_title '^Chrome' 'x Chrome' || false
	run foundation_match_title 'notepad++' 'Edit - Notepad++'
	[ "$status" -eq 0 ]
	# bash's complaint about the invalid pattern stays off the terminal.
	[ -z "$output" ]
	! foundation_match_title 'notepad++' 'Edit - Notepad' || false
}

@test "match_any: exact process name or title pattern" {
	foundation_match_any Code '' Code
	foundation_match_any Firefox 'YouTube' '*YouTube*'
	! foundation_match_any Firefox 'Reddit' '*YouTube*' Code || false
}

@test "title segment: a similarly named folder is not a match" {
	run foundation_title_has_segment "main.ts $EM myapp-ui" MyApp
	[ "$status" -ne 0 ]
	run foundation_title_has_segment "Program.cs - myapp-ui - Visual Studio Code" MyApp
	[ "$status" -ne 0 ]
	run foundation_title_has_segment "main.ts $EM Visual Studio Code" Studio
	[ "$status" -ne 0 ]
}

@test "title segment: the folder segment with either separator, any case" {
	foundation_title_has_segment "main.ts $EM MyApp" MyApp
	foundation_title_has_segment "MyApp" myapp
	foundation_title_has_segment "main.ts $EM MyApp $EM Work" MyApp
	foundation_title_has_segment "Program.cs - MyApp - Visual Studio Code" MyApp
}

@test "title segment: a leading dirty marker is ignored" {
	DOT=$(printf '\342\227\217')
	foundation_title_has_segment "$DOT main.ts $EM MyApp" MyApp
	foundation_title_has_segment "$DOT MyApp $EM Visual Studio Code" MyApp
}

@test "title segment: a folder and a workspace of the same name stay distinct" {
	run foundation_title_has_segment "x.ts $EM MyApp (Workspace)" MyApp
	[ "$status" -ne 0 ]
	foundation_title_has_segment "x.ts $EM MyApp (Workspace)" "MyApp (Workspace)"
	run foundation_title_has_segment "x.ts $EM MyApp" "MyApp (Workspace)"
	[ "$status" -ne 0 ]
}

@test "title segment: literal match, blank candidates skipped, any candidate wins" {
	run foundation_title_has_segment "x.ts $EM MyAppX" 'MyApp*'
	[ "$status" -ne 0 ]
	run foundation_title_has_segment "x.ts $EM ab" 'a?'
	[ "$status" -ne 0 ]
	run foundation_title_has_segment "x.ts $EM MyApp" '' '  '
	[ "$status" -ne 0 ]
	foundation_title_has_segment "x.ts $EM Other" '' Nope other
	foundation_title_has_segment "x.ts $EM My - App" 'My - App'
}

@test "title segment: the caller's nocasematch is kept" {
	foundation_title_has_segment "x.ts $EM MyApp" myapp
	run shopt -q nocasematch
	[ "$status" -ne 0 ]
	shopt -s nocasematch
	foundation_title_has_segment "x.ts $EM MyApp" myapp
	shopt -q nocasematch
	shopt -u nocasematch
}

@test "flag names: Windows spelling converts to Unix" {
	[ "$(foundation_flag_name -TimeoutSeconds)" = "--timeout-seconds" ]
	[ "$(foundation_flag_name -Skip)" = "--skip" ]
	[ "$(foundation_flag_name --already)" = "--already" ]
	[ "$(foundation_flag_name -v)" = "-v" ]
}

# A throwaway command whose header documents FLAGS; it prints what foundation_normalize_args made
# of its arguments, one per line. Usage: flag_command NAME FLAGS
flag_command() {
	printf '#!/usr/bin/env bash\n# %s - a test command.\n#\n# Usage: %s %s\n. "%s/lib/foundation.sh"\nfoundation_normalize_args "$@"\nprintf "%%s\\n" "${FOUNDATION_ARGS[@]}"\n' \
		"$1" "$1" "$2" "$UNIX_DIR" >"$BATS_TEST_TMPDIR/$1"
}

@test "normalize: -WhatIf is the dry run of a command that documents one, an error elsewhere" {
	flag_command WithDryRun '[--dry-run] [--max-age-days N]'
	run "${BASH:-bash}" "$BATS_TEST_TMPDIR/WithDryRun" -WhatIf -MaxAgeDays 3
	[ "$status" -eq 0 ]
	[ "$output" = $'--dry-run\n--max-age-days\n3' ]
	run "${BASH:-bash}" "$BATS_TEST_TMPDIR/WithDryRun" -whatif:\$true
	[ "$output" = --dry-run ]
	flag_command NoDryRun '[--force]'
	run "${BASH:-bash}" "$BATS_TEST_TMPDIR/NoDryRun" -WhatIf
	[ "$status" -eq 1 ]
	[[ $output == *"NoDryRun has no dry run (-WhatIf) - nothing was done"* ]]
	# A command that documents its own --what-if keeps it.
	flag_command OwnWhatIf '[--dry-run | --what-if]'
	run "${BASH:-bash}" "$BATS_TEST_TMPDIR/OwnWhatIf" -WhatIf
	[ "$output" = --what-if ]
}

@test "normalize: -Confirm, -Debug and -ErrorAction stop a command that does not document them" {
	flag_command Plain '[--force]'
	for flag in -Confirm -Confirm:\$false -Debug -ErrorAction; do
		run "${BASH:-bash}" "$BATS_TEST_TMPDIR/Plain" "$flag" SilentlyContinue
		[ "$status" -eq 1 ]
		[[ $output == *"Plain does not take $flag - nothing was done"* ]]
	done
	run "${BASH:-bash}" "$BATS_TEST_TMPDIR/Plain" -Force
	[ "$status" -eq 0 ]
	[ "$output" = --force ]
}

@test "normalize: a Windows name the header documents matches in any case" {
	# The Windows-style names line of a header puts the flag into the documented set, so the
	# lowercase spelling PowerShell accepts reaches the command as the flag, not as a name.
	flag_command Patterns '[PATTERN...]
# Windows-style names: --test-name (-TestName) is ignored: the names after it are patterns'
	run "${BASH:-bash}" "$BATS_TEST_TMPDIR/Patterns" -testname layout
	[ "$status" -eq 0 ]
	[ "$output" = $'--test-name\nlayout' ]
}

@test "normalize: a PowerShell abbreviation takes the one flag it starts, an ambiguous one stops" {
	flag_command Abbrev '[--alongside] [--include-current] [--include-default-branch] [--timeout-seconds N]'
	run "${BASH:-bash}" "$BATS_TEST_TMPDIR/Abbrev" Example -Along -IncludeC -Time 5
	[ "$status" -eq 0 ]
	[ "$output" = $'Example\n--alongside\n--include-current\n--timeout-seconds\n5' ]
	run "${BASH:-bash}" "$BATS_TEST_TMPDIR/Abbrev" -Include
	[ "$status" -eq 1 ]
	[[ $output == *"-Include is ambiguous (--include-current --include-default-branch)"* ]]
	# The Unix spelling is never abbreviated, and a prefix of nothing documented stays as it is.
	run "${BASH:-bash}" "$BATS_TEST_TMPDIR/Abbrev" --along -Browser
	[ "$output" = $'--along\n--browser' ]
	# A single letter is a short option, never an abbreviation, even where it is ambiguous.
	flag_command Short '[--verbose] [--vscode-workspace NAME]'
	run "${BASH:-bash}" "$BATS_TEST_TMPDIR/Short" -v
	[ "$status" -eq 0 ]
	[ "$output" = -v ]
}

@test "split_list: comma lists, blanks and the trailing comma of the PowerShell form" {
	names=()
	foundation_split_list names 'Server,Client'
	foundation_split_list names 'Api,'
	foundation_split_list names ' Web , '
	foundation_split_list names 'My Project'
	[ "${#names[@]}" -eq 5 ]
	[ "${names[*]}" = 'Server Client Api Web My Project' ]
	[ "${names[4]}" = 'My Project' ]
}

@test "whole numbers within a range" {
	foundation_whole_number 1 1 100
	foundation_whole_number 100 1 100
	foundation_whole_number 07 1 100
	! foundation_whole_number 0 1 100 || false
	! foundation_whole_number 101 1 100 || false
	! foundation_whole_number -1 1 100 || false
	! foundation_whole_number 1.5 1 100 || false
	! foundation_whole_number '' 1 100 || false
	! foundation_whole_number --what-if 1 100 || false
	! foundation_whole_number 99999999999999999999 1 100 || false
}

@test "expand_path: tilde, variables, DEFAULT" {
	[ "$(foundation_expand_path '~/x')" = "$HOME/x" ]
	[ "$(foundation_expand_path '$HOME/y')" = "$HOME/y" ]
	[ "$(foundation_expand_path DEFAULT)" = "$HOME" ]
}

@test "ieq: case-insensitive equality, no wildcards, the caller's nocasematch kept" {
	foundation_ieq DockPins dockpins
	run foundation_ieq DockPins Dock
	[ "$status" -ne 0 ]
	run foundation_ieq 'Dock*' DockPins
	[ "$status" -ne 0 ]
	foundation_ieq '' ''
	foundation_ieq Abc aBC
	run shopt -q nocasematch
	[ "$status" -ne 0 ]
	shopt -s nocasematch
	foundation_ieq Abc aBC
	shopt -q nocasematch
	shopt -u nocasematch
}

@test "timeout: a command past its limit is stopped with 124, one within it keeps its status and output" {
	SECONDS=0
	run foundation_timeout 1 sleep 30
	[ "$status" -eq 124 ]
	[ "$SECONDS" -lt 10 ]
	run foundation_timeout 5 sh -c 'echo done; exit 3'
	[ "$status" -eq 3 ]
	[ "$output" = done ]
}
