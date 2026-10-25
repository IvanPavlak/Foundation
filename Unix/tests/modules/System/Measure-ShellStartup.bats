#!/usr/bin/env bats
# Measure-ShellStartup against a stand-in shell that honours FOUNDATION_STARTUP_SKIP and writes the
# trace: the additive walk adds one stage per row from Core (after a bare row for zsh and bash), the
# leave-one-out walk drops one stage per row from Full, --stages narrows the walk, every
# configuration runs --runs times, the statistics are the documented ones (the median of an even
# count is the mean of the two middle values), and no shell can reach this terminal.

load ../../helpers

setup() {
	setup_foundation
	shell=$BATS_TEST_TMPDIR/shell
	# Each counted start (the warm-up writes its trace to /dev/null) takes the next of VALUES
	# (default 5 9 7, round and round) as every stage's time, and writes two lines the reader must
	# ignore: one without a tab and one whose time is not a number.
	cat >"$shell" <<'SH'
#!/bin/sh
printf '%s|%s|%s\n' "$FOUNDATION_STARTUP_SKIP" "$FOUNDATION_TTY" "$*" >>"$BATS_TEST_TMPDIR/starts"
[ "$FOUNDATION_STARTUP_TRACE" = /dev/null ] && exit 0
n=$(($(cat "$BATS_TEST_TMPDIR/count" 2>/dev/null || echo 0) + 1))
echo "$n" >"$BATS_TEST_TMPDIR/count"
set -- ${VALUES:-5 9 7}
shift $(((n - 1) % $#))
for stage in LineEditing Aliases Prompt Plugins Icons Greeting RepositoryUpdate; do
	case ",$FOUNDATION_STARTUP_SKIP," in *",$stage,"*) continue ;; esac
	printf '%s\t%s\n' "$stage" "$1" >>"$FOUNDATION_STARTUP_TRACE"
	printf '%s 1000\n%s\tslow\n' "$stage" "$stage" >>"$FOUNDATION_STARTUP_TRACE"
done
SH
	chmod +x "$shell"
	export BATS_TEST_TMPDIR
	cmd=$UNIX_DIR/modules/System/bin/Measure-ShellStartup
}

# The InShell column of the row named NAME in --pass-thru output.
in_shell_of() { awk -F'\t' -v n="$1" '$1 == n { print $7 }' <<<"$output"; }

@test "additive: Core skips every stage, each row adds the next one, N runs each" {
	run "${BASH:-bash}" "$cmd" --runs 2 --shell "$shell"
	[ "$status" -eq 0 ]
	[[ $output == *"Core"* ]]
	[[ $output == *"+ FastfetchImageLogo"* ]]
	[[ $output == *"+ RepositoryUpdate"* ]]
	# No bare row for a shell that is neither zsh nor bash: one warm-up, then 10 configurations x 2 runs.
	[[ $output != *"bare"* ]]
	[ "$(grep -c . "$BATS_TEST_TMPDIR/starts")" -eq 21 ]
	grep -qxF 'LineEditing,Aliases,Prompt,Plugins,Icons,Greeting,FastfetchImageLogo,OnefetchStyle,RepositoryUpdate|/dev/null|-i -c exit' "$BATS_TEST_TMPDIR/starts"
	grep -qxF 'Prompt,Plugins,Icons,Greeting,FastfetchImageLogo,OnefetchStyle,RepositoryUpdate|/dev/null|-i -c exit' "$BATS_TEST_TMPDIR/starts"
	# The greeting names come after Greeting: the + Greeting row still leaves them out.
	grep -qxF 'FastfetchImageLogo,OnefetchStyle,RepositoryUpdate|/dev/null|-i -c exit' "$BATS_TEST_TMPDIR/starts"
}

@test "--leave-one-out and --mode Isolated: Full, then each stage skipped alone" {
	run "${BASH:-bash}" "$cmd" --runs 1 --shell "$shell" --leave-one-out
	[ "$status" -eq 0 ]
	[[ $output == *"Full"* ]]
	[[ $output == *"- Greeting"* ]]
	grep -qxF 'Greeting|/dev/null|-i -c exit' "$BATS_TEST_TMPDIR/starts"
	grep -qxF '|/dev/null|-i -c exit' "$BATS_TEST_TMPDIR/starts"
	run "${BASH:-bash}" "$cmd" --runs 1 --shell "$shell" -Mode isolated
	[ "$status" -eq 0 ]
	[[ $output == *"- OnefetchStyle"* ]]
	[[ $output != *"Core"* ]]
	run "${BASH:-bash}" "$cmd" --runs 1 --shell "$shell" --mode Cumulative
	[[ $output == *"Core"* ]]
}

@test "a bad run count, mode or stage, or a missing shell, fails before any start" {
	run "${BASH:-bash}" "$cmd" --runs 0 --shell "$shell"
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" --runs 51 --shell "$shell"
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" --mode Sideways --shell "$shell"
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" --stages Prompt NoSuchStage --shell "$shell"
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" --shell "$BATS_TEST_TMPDIR/no-shell"
	[ "$status" -ne 0 ]
	[ ! -e "$BATS_TEST_TMPDIR/starts" ]
	run "${BASH:-bash}" "$cmd" --runs 50 --shell "$shell" --stages Prompt --pass-thru
	[ "$status" -eq 0 ]
}

@test "--stages walks only the named stages, in any case; the others stay out of every row" {
	run "${BASH:-bash}" "$cmd" --runs 1 --shell "$shell" --stages greeting,PROMPT --pass-thru
	[ "$status" -eq 0 ]
	[ "$(cut -f1 <<<"$output" | paste -sd'|' -)" = 'Configuration|Core|+ Greeting|+ Prompt' ]
	grep -qxF 'LineEditing,Aliases,Plugins,Icons,FastfetchImageLogo,OnefetchStyle,RepositoryUpdate,Prompt|/dev/null|-i -c exit' "$BATS_TEST_TMPDIR/starts"
	grep -qxF 'LineEditing,Aliases,Plugins,Icons,FastfetchImageLogo,OnefetchStyle,RepositoryUpdate|/dev/null|-i -c exit' "$BATS_TEST_TMPDIR/starts"
}

@test "a zsh or bash gets a bare row first, started without its rc, and Core's Delta is against it" {
	mkdir -p "$BATS_TEST_TMPDIR/bin"
	cp "$shell" "$BATS_TEST_TMPDIR/bin/zsh"
	run "${BASH:-bash}" "$cmd" --runs 1 --shell "$BATS_TEST_TMPDIR/bin/zsh" --stages Prompt --pass-thru
	[ "$status" -eq 0 ]
	[ "$(sed -n 2p <<<"$output" | cut -f1)" = "bare (no rc)" ]
	[[ $(sed -n 3p <<<"$output" | cut -f6) =~ ^-?[0-9]+$ ]]
	grep -qxF '|/dev/null|-f -i -c exit' "$BATS_TEST_TMPDIR/starts"
	cp "$shell" "$BATS_TEST_TMPDIR/bin/bash"
	run "${BASH:-bash}" "$cmd" --runs 1 --shell "$BATS_TEST_TMPDIR/bin/bash" --stages Prompt
	grep -qxF '|/dev/null|--norc -i -c exit' "$BATS_TEST_TMPDIR/starts"
}

@test "InShell is the median of the stage's own times; lines without a tab or a number are ignored" {
	# Core takes the first three starts (5 9 7), + Prompt the next three (5 9 7 again).
	run "${BASH:-bash}" "$cmd" --runs 3 --shell "$shell" --stages Prompt --pass-thru
	[ "$status" -eq 0 ]
	[ "$(in_shell_of "+ Prompt")" = 7 ]
	[ "$(in_shell_of Core)" = - ]
}

@test "the median of an even count is the mean of the two middle values" {
	VALUES='5 9' run "${BASH:-bash}" "$cmd" --runs 2 --shell "$shell" --stages Prompt --pass-thru
	[ "$status" -eq 0 ]
	[ "$(in_shell_of "+ Prompt")" = 7 ]
}

@test "--pass-thru: one header and one row per configuration; Delta is the median minus the previous row's" {
	run "${BASH:-bash}" "$cmd" --runs 3 --shell "$shell" --pass-thru
	[ "$status" -eq 0 ]
	[ "$(head -n 1 <<<"$output")" = "$(printf 'Configuration\tRuns\tMin\tMedian\tMax\tDelta\tInShell')" ]
	[ "$(grep -c . <<<"$output")" -eq 11 ]
	awk -F'\t' 'NR > 1 {
		if ($2 != 3 || $3 > $4 || $4 > $5) bad = 1
		if (NR == 2 && $6 != "-") bad = 1
		if (NR > 2 && $6 != $4 - previous) bad = 1
		previous = $4
	} END { exit bad }' <<<"$output"
	# Leave-one-out: Delta is Full's median minus the row's.
	run "${BASH:-bash}" "$cmd" --runs 1 --shell "$shell" --leave-one-out --pass-thru
	awk -F'\t' 'NR == 2 { full = $4 } NR > 2 && $6 != full - $4 { bad = 1 } END { exit bad }' <<<"$output"
}
