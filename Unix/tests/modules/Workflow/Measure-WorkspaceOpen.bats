#!/usr/bin/env bats
# Measure-WorkspaceOpen against the platform stand-ins: the variants and run plan of --dry-run, the
# refusals before anything runs, --report over a recorded session (--reference, the retries),
# --list-sessions, and real (stubbed) runs that record their measurement rows: the --max-minutes
# budget (its clock a stand-in) and an open that fails (Error). Every run gets a harmless
# --teardown (never the default Kill-All), sleep is a stand-in so the countdown and settle waits
# are instant, and the measured workspace only focuses a desktop on the AeroSpace stand-in.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	copy_fixture_config
	cat >>"$FOUNDATION_CONFIG_DIR/workspaces.conf" <<'CONF'

[Measure]
Focus-VirtualDesktop 2

[Closer]
Terminate-WindowsTerminalTabs --only-current
Focus-VirtualDesktop 2

[Picker]
Open-Project
Focus-VirtualDesktop 2
CONF
	stub_tool sleep 'exit 0'
	torn=$BATS_TEST_TMPDIR/teardown.log
	measurements=$FOUNDATION_STATE_DIR/WorkspaceOpenMeasurements.csv
	cmd=$UNIX_DIR/modules/Workflow/bin/Measure-WorkspaceOpen
}

# Runs the command with a teardown that only logs, ahead of any `--` pass-through.
measure() {
	run "${BASH:-bash}" "$cmd" --teardown "echo torn >>'$torn'" --settle-seconds 0 "$@"
}

# The plan lines of a dry run, "KIND round N => VARIANT".
plan_lines() {
	printf '%s\n' "$output" | grep -E '^ *(WarmUp|Measured) round ' | sed -E 's/^ +//'
}

nothing_ran() {
	! stub_called '^aerospace workspace' || return 1
	[ ! -e "$torn" ] || return 1
	[ ! -e "$measurements" ]
}

@test "--dry-run: the baseline plus one flipped variant per setting, nothing opened" {
	measure Measure --dry-run --runs 1
	[ "$status" -eq 0 ]
	[[ $output == *"variant Baseline (layout-early-move=off layout-stable-ms=500)"* ]]
	[[ $output == *"variant layout-early-move=on"* ]]
	[[ $output == *"variant layout-stable-ms=1000"* ]]
	# One warm-up under the baseline, then one round of the three variants.
	[ "$(plan_lines | wc -l | tr -d ' ')" -eq 4 ]
	[[ $(plan_lines | head -n 1) == "WarmUp round 1 => Baseline"* ]]
	nothing_ran
}

@test "--full-factorial plans every combination" {
	measure Measure --dry-run --full-factorial --runs 2 --warm-up 0
	[ "$status" -eq 0 ]
	[[ $output == *"variant layout-early-move=on layout-stable-ms=1000"* ]]
	[[ $output == *"variant layout-early-move=off layout-stable-ms=500"* ]]
	[ "$(plan_lines | wc -l | tr -d ' ')" -eq 8 ]
	nothing_ran
}

@test "--variant runs exactly the variants given, --setting picks the settings flipped" {
	measure Measure --dry-run --warm-up 0 --runs 1 --variant "Fast:layout-early-move=on" --variant "Slow:layout-early-move=off"
	[ "$(plan_lines | paste -sd'|' -)" = "Measured round 1 => Fast|Measured round 1 => Slow" ]
	measure Measure --dry-run --warm-up 0 --runs 1 --setting layout-stable-ms
	[ "$(plan_lines | wc -l | tr -d ' ')" -eq 2 ]
	[[ $output == *"variant layout-stable-ms=1000"* ]]
	[[ $output != *"variant layout-early-move"* ]]
}

@test "interleaved rounds alternate the variants, sequential runs each variant's rounds together" {
	measure Measure --dry-run --warm-up 0 --runs 2 --variant A:layout-early-move=on --variant B:layout-early-move=off
	[ "$(plan_lines | paste -sd'|' -)" = "Measured round 1 => A|Measured round 1 => B|Measured round 2 => A|Measured round 2 => B" ]
	measure Measure --dry-run --warm-up 0 --runs 2 --order Sequential --variant A:layout-early-move=on --variant B:layout-early-move=off
	[ "$(plan_lines | paste -sd'|' -)" = "Measured round 1 => A|Measured round 2 => A|Measured round 1 => B|Measured round 2 => B" ]
}

@test "--order shuffled with a seed plans every variant once per round" {
	measure Measure --dry-run --warm-up 0 --runs 2 --order shuffled --seed 7 --variant A:x=1 --variant B:x=2 --variant C:x=3
	[ "$status" -eq 0 ]
	[ "$(plan_lines | grep -c 'round 1 =>')" -eq 3 ]
	[ "$(plan_lines | grep 'round 2 =>' | sed 's/.*=> //' | sort | paste -sd' ' -)" = "A B C" ]
}

@test "bad options, counts, orders and settings fail before anything runs" {
	measure Measure --no-such-option
	[ "$status" -ne 0 ]
	measure Measure --runs many
	[ "$status" -ne 0 ]
	measure Measure --order random
	[ "$status" -ne 0 ]
	measure Measure --setting no-such-setting
	[ "$status" -ne 0 ]
	nothing_ran
}

@test "an unknown workspace, or none with no Example configured, fails before anything runs" {
	measure NoSuchWorkspace
	[ "$status" -ne 0 ]
	measure
	[ "$status" -ne 0 ]
	nothing_ran
}

@test "a workspace that closes the calling terminal tab is refused" {
	measure Closer
	[ "$status" -ne 0 ]
	nothing_ran
}

@test "a tab-closing line behind a layout-set scope is refused too, whatever the set" {
	printf '\n[ScopedCloser]\n%%NoSuchSet Terminate-WindowsTerminalTabs --only-current\nFocus-VirtualDesktop 2\n' >>"$FOUNDATION_CONFIG_DIR/workspaces.conf"
	measure ScopedCloser
	[ "$status" -ne 0 ]
	nothing_ran
}

@test "a bare Open-Project needs a project on the command line" {
	measure Picker
	[ "$status" -ne 0 ]
	nothing_ran
	measure Picker SampleApi --dry-run
	[ "$status" -eq 0 ]
}

@test "--report summarizes a session: the first variant is the reference, the others get a verdict" {
	mkdir -p "$FOUNDATION_STATE_DIR"
	{
		echo 'Session,Variant,Round,Kind,Workspace,Settings,Timestamp,TotalSeconds,ActionsSeconds,LayoutSeconds,WaitSeconds,ArrangeSeconds,Found,Expected,Outcome'
		echo 'S1,Base,1,WarmUp,Measure,x=1,t,50.0,1,1,1,1,1,1,Applied'
		echo 'S1,Base,1,Measured,Measure,x=1,t,10.0,1,1,1,1,1,1,Applied'
		echo 'S1,Base,2,Measured,Measure,x=1,t,12.0,1,1,1,1,1,1,Applied'
		echo 'S1,Alt,1,Measured,Measure,x=2,t,5.0,1,1,1,1,1,1,Applied'
		echo 'S1,Alt,2,Measured,Measure,x=2,t,6.0,1,1,1,1,1,1,Applied'
		echo 'S2,Other,1,Measured,Measure,x=3,t,3.0,1,1,1,1,1,1,Applied'
	} >"$measurements"
	run "${BASH:-bash}" "$cmd" --report S1
	[ "$status" -eq 0 ]
	# Base: 2 measured runs (the warm-up is not counted), median 11.0.
	[[ $(printf '%s\n' "$output" | grep -E '^  Base ') == *" 2 "*"11.0s"*Reference* ]]
	[[ $(printf '%s\n' "$output" | grep -E '^  Alt ') == *"-5.5"*Faster* ]]
	[[ $output != *Other* ]]
	# Without a session: the last recorded one.
	run "${BASH:-bash}" "$cmd" --report
	[ "$status" -eq 0 ]
	[[ $output == *Other* ]]
	[[ $output != *Alt* ]]
}

@test "--report without measurements is an error" {
	run "${BASH:-bash}" "$cmd" --report
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" --list-sessions
	[ "$status" -ne 0 ]
}

# A recorded file of two sessions: S1 (Base and Alt, with a warm-up) and S2 (one variant).
two_sessions() {
	mkdir -p "$FOUNDATION_STATE_DIR"
	{
		echo 'Session,Variant,Round,Kind,Workspace,Settings,Timestamp,TotalSeconds,ActionsSeconds,LayoutSeconds,WaitSeconds,ArrangeSeconds,Found,Expected,Outcome,Attempts'
		echo 'S1,Base,1,WarmUp,Measure,x=1,2026-01-01T10:00:00,50.0,1,1,1,1,1,1,Applied,1'
		echo 'S1,Base,1,Measured,Measure,x=1,2026-01-01T10:01:00,10.0,1,1,1,1,1,1,Applied,1'
		echo 'S1,Base,2,Measured,Measure,x=1,2026-01-01T10:02:00,12.0,1,1,1,1,1,1,Applied,3'
		echo 'S1,Alt,1,Measured,Measure,x=2,2026-01-01T10:03:00,5.0,1,1,1,1,1,1,Applied,1'
		echo 'S1,Alt,2,Measured,Measure,x=2,2026-01-01T10:04:00,6.0,1,1,1,1,0,1,Partial,2'
		echo 'S2,Other,1,Measured,Picker,x=3,2026-01-02T09:00:00,3.0,1,1,1,1,1,1,Applied,1'
	} >"$measurements"
}

@test "--report counts retries and not-applied runs; a clean run is Applied at the first attempt" {
	two_sessions
	run "${BASH:-bash}" "$cmd" --report S1
	[ "$status" -eq 0 ]
	# Base: 2 runs, 1 clean (the other took 3 attempts: 2 retries), 0 not applied.
	read -r _ runs clean retries notapplied _ <<<"$(printf '%s\n' "$output" | grep -E '^  Base ')"
	[ "$runs $clean $retries $notapplied" = "2 1 2 0" ]
	read -r _ runs clean retries notapplied _ <<<"$(printf '%s\n' "$output" | grep -E '^  Alt ')"
	[ "$runs $clean $retries $notapplied" = "2 1 1 1" ]
}

@test "--reference compares with the named variant; an unknown one falls back to the first" {
	two_sessions
	run "${BASH:-bash}" "$cmd" --report S1 --reference Alt
	[ "$status" -eq 0 ]
	[[ $(printf '%s\n' "$output" | grep -E '^  Alt ') == *Reference* ]]
	[[ $(printf '%s\n' "$output" | grep -E '^  Base ') != *Reference* ]]
	run "${BASH:-bash}" "$cmd" --report S1 --reference NoSuchVariant
	[ "$status" -eq 0 ]
	[[ $output == *"No variant [NoSuchVariant] in session S1"* ]]
	[[ $(printf '%s\n' "$output" | grep -E '^  Base ') == *Reference* ]]
}

@test "--list-sessions lists each session with its workspace, start, opens and variants" {
	two_sessions
	run "${BASH:-bash}" "$cmd" --list-sessions
	[ "$status" -eq 0 ]
	# S1: 5 opens (the warm-up included), 4 measured, 2 variants; S2 after it.
	[ "$(printf '%s\n' "$output" | grep -E '^  S1 ' | awk '{ print $2, $3, $4, $5, $6 }')" = "Measure 2026-01-01T10:00:00 5 4 2" ]
	[ "$(printf '%s\n' "$output" | grep -E '^  S2 ' | awk '{ print $2, $4, $5, $6 }')" = "Picker 1 1 1" ]
	[ "$(printf '%s\n' "$output" | grep -E '^  S[12] ' | awk '{ print $1 }' | paste -sd' ' -)" = "S1 S2" ]
	[ ! -e "$torn" ]
}

@test "a run opens the workspace with its projects and pass-through, tears down, and records the row" {
	measure Measure SampleApi --runs 1 --warm-up 0 --variant "Only:layout-early-move=on" -- -v
	[ "$status" -eq 0 ]
	stub_called '^aerospace workspace -- 2'
	[[ $output == *"projects [SampleApi]"* ]]
	# One teardown before the run, one after the experiment.
	[ "$(wc -l <"$torn" | tr -d ' ')" -eq 2 ]
	[ "$(wc -l <"$measurements" | tr -d ' ')" -eq 2 ]
	[ "$(tail -n 1 "$measurements" | cut -d, -f2,3,4,5,6,15)" = "Only,1,Measured,Measure,layout-early-move=on,NoLayout" ]
	# The benchmark row the open wrote is stamped as an experiment row.
	[[ $(tail -n 1 "$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv" | cut -d, -f14) == "Measure-WorkspaceOpen "* ]]
}

@test "benchmark off in workspaces.conf: the experiment's opens still record their rows" {
	printf 'benchmark off\n' >"$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	measure Measure --runs 1 --warm-up 0 --variant "Only:layout-early-move=on"
	[ "$status" -eq 0 ]
	[ "$(tail -n 1 "$measurements" | cut -d, -f2,6,15)" = "Only,layout-early-move=on,NoLayout" ]
}

@test "--max-minutes stops starting opens once the budget is spent, and still summarizes" {
	# The clock stand-in: 40 seconds pass on every read, so the 60-second budget allows the first
	# open (40 s) and stops before the second (80 s).
	printf '#!/bin/sh\nn=$(cat "%s/clock" 2>/dev/null || echo 0)\necho $((n + 40)) >"%s/clock"\necho "$n"\n' "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR" >"$BATS_TEST_TMPDIR/measure-clock"
	chmod +x "$BATS_TEST_TMPDIR/measure-clock"
	FOUNDATION_MEASURE_CLOCK=$BATS_TEST_TMPDIR/measure-clock measure Measure --runs 3 --warm-up 0 --variant "Only:layout-early-move=on" --max-minutes 1
	[ "$status" -eq 0 ]
	[[ $output == *"--max-minutes 1 reached"* ]]
	# One of the three planned opens ran and was recorded.
	[ "$(tail -n +2 "$measurements" | grep -c .)" -eq 1 ]
	[[ $output == *"Summary - session"*"(1 open(s))"* ]]
	[ "$(printf '%s\n' "$output" | grep -E '^  Only ' | awk '{ print $2 }')" = 1 ]
}

@test "an open that fails without a benchmark row is recorded as Error and counted as not applied" {
	# AeroSpace never answers, so Open-Workspace gives up before it writes a row.
	: >"$BATS_TEST_TMPDIR/aerospace-down"
	measure Measure --runs 1 --warm-up 0 --variant "Only:layout-early-move=on"
	[ "$status" -eq 0 ]
	[ "$(tail -n 1 "$measurements" | cut -d, -f2,15)" = "Only,Error" ]
	read -r _ runs clean retries notapplied _ <<<"$(printf '%s\n' "$output" | grep -E '^  Only ')"
	[ "$runs $clean $retries $notapplied" = "1 0 0 1" ]
}

@test "a measurement file from before the Attempts column keeps its rows and gains the header" {
	mkdir -p "$FOUNDATION_STATE_DIR"
	printf 'Session,Variant,Round,Kind,Workspace,Settings,Timestamp,TotalSeconds,ActionsSeconds,LayoutSeconds,WaitSeconds,ArrangeSeconds,Found,Expected,Outcome\nOld,Base,1,Measured,Measure,x=1,t,10.0,1,1,1,1,1,1,Applied\n' >"$measurements"
	measure Measure --runs 1 --warm-up 0 --variant "Only:layout-early-move=on"
	[ "$status" -eq 0 ]
	[ "$(head -n 1 "$measurements" | cut -d, -f16)" = Attempts ]
	[ "$(sed -n 2p "$measurements")" = 'Old,Base,1,Measured,Measure,x=1,t,10.0,1,1,1,1,1,1,Applied' ]
	# The new row carries the open's attempt count (0: the workspace has no layout).
	[ "$(tail -n 1 "$measurements" | cut -d, -f15,16)" = "NoLayout,0" ]
}

@test "an open that writes no benchmark row is recorded as NoRow" {
	# A benchmark file that cannot be appended to (its header already current, so nothing
	# rewrites it): the open runs but adds no row.
	mkdir -p "$FOUNDATION_STATE_DIR"
	echo 'Timestamp,Workspace,Machine,LayoutSet,TotalSeconds,ActionsSeconds,LayoutSeconds,WaitSeconds,ArrangeSeconds,Found,Expected,Outcome,EarlyMove,Source,Mode,Attempts' >"$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv"
	chmod a-w "$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv"
	measure Measure --runs 1 --warm-up 0 --variant "Only:layout-early-move=on"
	chmod u+w "$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv"
	[ "$status" -eq 0 ]
	[ "$(tail -n 1 "$measurements" | cut -d, -f2,15)" = "Only,NoRow" ]
}

@test "a setting without a line counts as the shipped base value in the Baseline" {
	printf -- '-layout-early-move off\n-layout-stable-ms 500\n' >"$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	measure Measure --dry-run --runs 1
	[ "$status" -eq 0 ]
	[[ $output == *"variant Baseline (layout-early-move=off layout-stable-ms=500)"* ]]
	[[ $output == *"variant layout-early-move=on"* ]]
	[[ $output == *"variant layout-stable-ms=1000"* ]]
}

@test "the Windows spellings work before --, and -WhatIf is the dry run" {
	measure Measure -Runs 1 -WarmUp 0 -DryRun
	[ "$status" -eq 0 ]
	[ "$(plan_lines | wc -l | tr -d ' ')" -eq 3 ]
	nothing_ran
	measure Measure -WhatIf --runs 1 --warm-up 0 -- -TimeoutSeconds 5
	[ "$status" -eq 0 ]
	nothing_ran
}
