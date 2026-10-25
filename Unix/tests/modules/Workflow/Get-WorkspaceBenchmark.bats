#!/usr/bin/env bats
# Get-WorkspaceBenchmark against a benchmark CSV in the test state folder: which rows are shown
# (workspace filter, --last and --last 0, the benchmark-history default, Measure-WorkspaceOpen rows
# only with --include-measured or --source), --csv, the median line per workspace, mode and
# early-move mode with its retries, --summary (the median lines alone), --formatted, and bad input.
# It only reads the CSV - no workspace is ever opened.

load ../../helpers

header='Timestamp,Workspace,Machine,LayoutSet,TotalSeconds,ActionsSeconds,LayoutSeconds,WaitSeconds,ArrangeSeconds,Found,Expected,Outcome,EarlyMove,Source'

setup() {
	setup_foundation
	copy_fixture_config
	mkdir -p "$FOUNDATION_STATE_DIR"
	csv=$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv
	{
		echo "$header"
		echo '2026-01-01T10:00:00,Alpha,PC,Work,10.0,4.0,6.0,2.0,4.0,3,3,Applied,on,'
		echo '2026-01-02T10:00:00,Beta,PC,Work,20.0,5.0,15.0,9.0,6.0,1,2,Partial,on,'
		echo '2026-01-03T10:00:00,Alpha,PC,Work,14.0,5.0,9.0,3.0,6.0,3,3,Applied,on,'
		echo '2026-01-04T10:00:00,Alpha,PC,Work,99.0,9.0,90.0,9.0,9.0,3,3,Applied,off,Measure-WorkspaceOpen 20260104-100000'
		echo '2026-01-05T10:00:00,Alpha,PC,Work,30.0,5.0,25.0,3.0,6.0,3,3,Applied,on,'
	} >"$csv"
	cmd=$UNIX_DIR/modules/Workflow/bin/Get-WorkspaceBenchmark
}

# The data rows of the output (after the column header of the table, before the median lines).
table_rows() {
	printf '%s\n' "$output" | grep -E '^  20[0-9]{2}-'
}

@test "the everyday rows are shown oldest first, measured rows left out" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(table_rows | wc -l | tr -d ' ')" -eq 4 ]
	[ "$(table_rows | head -n 1 | awk '{ print $1 }')" = 2026-01-01T10:00:00 ]
	[[ $output != *"99.0s"* ]]
}

@test "a median line per workspace and early-move mode closes the table" {
	run "${BASH:-bash}" "$cmd" Alpha
	[ "$status" -eq 0 ]
	# Alpha totals 10, 14, 30: median 14, three runs, all applied.
	[[ $output == *"median Alpha"*"early on"*"total 14.0s"*"over 3 run(s), 3 applied cleanly"* ]]
	[[ $output != *"median Beta"* ]]
}

@test "--include-measured adds the Measure-WorkspaceOpen rows under their own early-move mode" {
	run "${BASH:-bash}" "$cmd" Alpha --include-measured
	[ "$status" -eq 0 ]
	[ "$(table_rows | wc -l | tr -d ' ')" -eq 4 ]
	[[ $output == *"median Alpha"*"early off"*"total 99.0s"*"over 1 run(s)"* ]]
}

@test "workspace names filter case-insensitively, a comma list names several" {
	run "${BASH:-bash}" "$cmd" beta
	[ "$(table_rows | wc -l | tr -d ' ')" -eq 1 ]
	[[ $(table_rows) == *Beta*"1/2"*Partial* ]]
	run "${BASH:-bash}" "$cmd" alpha,BETA
	[ "$(table_rows | wc -l | tr -d ' ')" -eq 4 ]
}

@test "--last N keeps the most recent N rows" {
	run "${BASH:-bash}" "$cmd" --last 2
	[ "$status" -eq 0 ]
	[ "$(table_rows | awk '{ print $1 }' | paste -sd' ' -)" = "2026-01-03T10:00:00 2026-01-05T10:00:00" ]
}

@test "the default row count is benchmark-history of workspaces.conf" {
	printf 'benchmark-history 1\n' >"$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$(table_rows | awk '{ print $1 }')" = 2026-01-05T10:00:00 ]
}

@test "--summary prints only the median lines, as -Summary does on Windows; --formatted changes nothing" {
	run "${BASH:-bash}" "$cmd" -Summary
	[ "$status" -eq 0 ]
	[ -z "$(table_rows)" ]
	[[ $output != *"Outcome"* ]]
	[[ $output == *"median Alpha"*"total 14.0s"* ]]
	[[ $output == *"median Beta"* ]]
	table=$("${BASH:-bash}" "$cmd" Alpha)
	run "${BASH:-bash}" "$cmd" Alpha -Formatted
	[ "$status" -eq 0 ]
	[ "$output" = "$table" ]
}

@test "--summary and --csv do not combine" {
	run "${BASH:-bash}" "$cmd" --summary --csv
	[ "$status" -ne 0 ]
	[[ $output != *"$header"* ]]
}

@test "--csv prints the header and the selected rows as CSV" {
	run "${BASH:-bash}" "$cmd" Beta --csv
	[ "$status" -eq 0 ]
	[ "$output" = "$header"$'\n''2026-01-02T10:00:00,Beta,PC,Work,20.0,5.0,15.0,9.0,6.0,1,2,Partial,on,' ]
	run "${BASH:-bash}" "$cmd" --csv --include-measured --last 2
	[ "$(printf '%s\n' "$output" | sed -n 2p | cut -d, -f1)" = 2026-01-04T10:00:00 ]
}

@test "--last 0 shows every row" {
	printf 'benchmark-history 1\n' >"$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	run "${BASH:-bash}" "$cmd" --last 0
	[ "$status" -eq 0 ]
	[ "$(table_rows | wc -l | tr -d ' ')" -eq 4 ]
	run "${BASH:-bash}" "$cmd" --last 0 --include-measured
	[ "$(table_rows | wc -l | tr -d ' ')" -eq 5 ]
}

@test "--source keeps only that source's rows, measured included; a session id names its rows" {
	echo '2026-01-06T10:00:00,Alpha,PC,Work,50.0,5.0,45.0,3.0,6.0,3,3,Applied,on,Measure-WorkspaceOpen 20260106-100000' >>"$csv"
	run "${BASH:-bash}" "$cmd" --source "Measure-WorkspaceOpen 20260104-100000"
	[ "$status" -eq 0 ]
	[ "$(table_rows | awk '{ print $1 }')" = 2026-01-04T10:00:00 ]
	run "${BASH:-bash}" "$cmd" --source 20260106-100000
	[ "$(table_rows | awk '{ print $1 }')" = 2026-01-06T10:00:00 ]
	run "${BASH:-bash}" "$cmd" --source 20260104-100000,20260106-100000 --csv
	[ "$(printf '%s\n' "$output" | tail -n +2 | cut -d, -f1 | paste -sd' ' -)" = "2026-01-04T10:00:00 2026-01-06T10:00:00" ]
	run "${BASH:-bash}" "$cmd" --source 20991231-000000
	[ "$status" -eq 0 ]
	[ -z "$(table_rows)" ]
}

@test "the mode and the attempts split the medians; retries and not-applied runs are counted" {
	# Today's columns: Mode and Attempts after Source.
	{
		echo "$header,Mode,Attempts"
		echo '2026-02-01T10:00:00,Gamma,PC,Work,10.0,4.0,6.0,2.0,4.0,3,3,Applied,off,,Plain,1'
		echo '2026-02-02T10:00:00,Gamma,PC,Work,12.0,4.0,8.0,2.0,6.0,3,3,Applied,off,,Plain,3'
		echo '2026-02-03T10:00:00,Gamma,PC,Work,40.0,4.0,36.0,2.0,6.0,2,3,Partial,off,,Alongside,2'
	} >"$csv"
	run "${BASH:-bash}" "$cmd" Gamma
	[ "$status" -eq 0 ]
	[[ $(table_rows | sed -n 2p) == *Gamma*Plain*"3/3"*" 3  "*Applied* ]]
	# Plain: two runs, one clean (the other needed 3 attempts, 2 retries).
	[[ $output == *"median Gamma"*"Plain"*"early off"*"total 11.0s"*"over 2 run(s), 1 applied cleanly, 2 retries, 0 not applied"* ]]
	[[ $output == *"median Gamma"*"Alongside"*"total 40.0s"*"over 1 run(s), 0 applied cleanly, 1 retries, 1 not applied"* ]]
}

@test "rows from before the Mode and Attempts columns read as Plain with no attempt count" {
	run "${BASH:-bash}" "$cmd" Beta
	[[ $(table_rows) == *Beta*Plain*"1/2"*" -  "*Partial* ]]
}

@test "--last needs a number" {
	run "${BASH:-bash}" "$cmd" --last many
	[ "$status" -ne 0 ]
	[ -z "$(table_rows)" ]
}

@test "no recorded open, or none of the named workspace, shows no table and succeeds" {
	run "${BASH:-bash}" "$cmd" NoSuchWorkspace
	[ "$status" -eq 0 ]
	[ -z "$(table_rows)" ]
	rm "$csv"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -z "$(table_rows)" ]
}
