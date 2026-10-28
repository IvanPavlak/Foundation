#!/usr/bin/env bats
# lib/testrun.sh: the integration tag, the learned worker count (default, explore, confirm,
# settle, re-check, scoped cap), the worker history (another machine, malformed lines, the
# machine key), when a run may teach it, unknown run conditions, the queue order, the bats
# version check, the --changed selection over a miniature repository (commands, libraries,
# helpers, fixture workspaces, manifests, base config, comments ignored, the everything fallback
# for an untraced file), patterns, the own-subject rule of --quick and the selection preview, the
# run-condition sampler, the impact map, the lint trigger, the lint file list, the miss report and
# the results retention. The git-backed helpers are in testrun-git.bats, the contract in contract.bats.

load helpers

setup() {
	setup_foundation
	foundation_load testrun
	runs=$BATS_TEST_TMPDIR/runs
	: >"$runs"
}

# A miniature repository under $BATS_TEST_TMPDIR/repo with its corpus in $corpus: Cmd-One loads
# lib foo, Cmd-Two calls Cmd-One, Open-Workspace reads workspaces.conf, whose fixture names
# Cmd-One; every suite loads the helper, which loads lib config.
mini_repo() {
	repo=$BATS_TEST_TMPDIR/repo
	mkdir -p "$repo"/Unix/{lib,modules/A/bin,modules/B/bin,tests/modules/A,tests/modules/B,tests/fixtures/config}
	cd "$repo" || return 1
	printf 'foundation_load() { :; }\n' >Unix/lib/foundation.sh
	printf 'conf_read() { :; }\n' >Unix/lib/config.sh
	printf 'foo() { :; }\n' >Unix/lib/foo.sh
	printf '#!/usr/bin/env bash\nfoundation_load foo\nfoo\n' >Unix/modules/A/bin/Cmd-One
	printf '#!/usr/bin/env bash\n"$bin/Cmd-One" --quiet\n' >Unix/modules/A/bin/Cmd-Two
	printf '#!/usr/bin/env bash\nconf_read workspaces.conf\n' >Unix/modules/B/bin/Open-Workspace
	printf 'setup_foundation() { foundation_load config; }\n' >Unix/tests/helpers.bash
	printf '[Sample]\nCmd-One --flag\n' >Unix/tests/fixtures/config/workspaces.conf
	printf 'load ../../helpers\n@test "one" { run Cmd-One; }\n' >Unix/tests/modules/A/Cmd-One.bats
	printf 'load ../../helpers\n@test "two" { run Cmd-Two; }\n' >Unix/tests/modules/A/Cmd-Two.bats
	printf 'load ../../helpers\n@test "w" { run Open-Workspace Sample; }\n' >Unix/tests/modules/B/Open-Workspace.bats
	printf 'load helpers\n# Cmd-One is only named in this comment\n@test "o" { :; }\n' >Unix/tests/other.bats
	printf 'load helpers\n@test "docs" { ls "$DOTFILES_ROOT/docs/foundation/modules"; }\n' >Unix/tests/commands.bats
	corpus=$BATS_TEST_TMPDIR/corpus
	testrun_corpus "$corpus"
}

# The suites the changes (STATUS<TAB>PATH lines, one argument each) select, one per line.
picked() {
	printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/changes"
	testrun_select "$corpus" "$BATS_TEST_TMPDIR/changes" | testrun_selection_unique | cut -f1 | LC_ALL=C sort
}

@test "the integration tag is read from the file_tags line, alone or in a list" {
	printf '#!/usr/bin/env bats\n# bats file_tags=integration\n' >"$BATS_TEST_TMPDIR/a.bats"
	printf '# bats file_tags=slow,integration\n' >"$BATS_TEST_TMPDIR/b.bats"
	printf '# bats file_tags=integrations\n# integration in prose\n' >"$BATS_TEST_TMPDIR/c.bats"
	testrun_is_integration "$BATS_TEST_TMPDIR/a.bats"
	testrun_is_integration "$BATS_TEST_TMPDIR/b.bats"
	run testrun_is_integration "$BATS_TEST_TMPDIR/c.bats"
	[ "$status" -ne 0 ]
	run testrun_is_integration "$BATS_TEST_TMPDIR/missing.bats"
	[ "$status" -ne 0 ]
}

@test "worker count: no history uses min(CPU, cap)" {
	run testrun_worker_choice "$runs" 16 70 200000 0
	[ "$(cut -f1,3 <<<"$output")" = $'12\tDefault' ]
	run testrun_worker_choice "$runs" 8 70 200000 0
	[ "$(cut -f1 <<<"$output")" = 8 ]
}

@test "worker count: explores the upper neighbour, then the lower one, then confirms a faster one" {
	printf '12\t30\n12\t32\n' >"$runs"
	run testrun_worker_choice "$runs" 16 70 200000 0
	[ "$(cut -f1,3 <<<"$output")" = $'15\tExplore' ]
	printf '15\t25\n' >>"$runs"
	run testrun_worker_choice "$runs" 16 70 200000 0
	[ "$(cut -f1,3 <<<"$output")" = $'9\tExplore' ]
	printf '9\t40\n' >>"$runs"
	run testrun_worker_choice "$runs" 16 70 200000 0
	[ "$(cut -f1,3 <<<"$output")" = $'15\tConfirm' ]
}

@test "worker count: a count needs two samples to become the best, then it is used" {
	printf '12\t30\n12\t32\n15\t25\n9\t40\n15\t26\n19\t27\n11\t35\n' >"$runs"
	run testrun_worker_choice "$runs" 20 70 200000 0
	[ "$(cut -f1-3 <<<"$output")" = $'15\t15\tSettle' ]
	[[ $output == *"learned best 15"* ]]
}

@test "worker count: every 20th recorded run re-checks a neighbour" {
	for i in $(seq 1 10); do printf '12\t30\n15\t40\n9\t45\n'; done | head -20 >"$runs"
	run testrun_worker_choice "$runs" 16 70 200000 0
	[ "$(cut -f3 <<<"$output")" = Recheck ]
	[ "$(cut -f1 <<<"$output")" != 12 ]
}

@test "worker count: a scoped run never explores and gives no worker less than the minimum work" {
	printf '12\t30\n12\t32\n' >"$runs"
	run testrun_worker_choice "$runs" 16 70 5000 1
	[ "$(cut -f1,3 <<<"$output")" = $'3\tScoped' ]
	run testrun_worker_choice "$runs" 16 2 900000 1
	[ "$(cut -f1 <<<"$output")" = 2 ]
	run testrun_worker_choice "$runs" 16 70 900000 1
	[ "$(cut -f1 <<<"$output")" = 12 ]
}

@test "only a clean full run with the lint on a quiet machine is recorded" {
	run testrun_recordable 0 0 0 0 on 1.5 16
	[ "$status" -eq 0 ]
	run testrun_recordable 1 0 0 0 on 1.5 16
	[ "$status" -ne 0 ]
	[ "$output" = "scoped run" ]
	run testrun_recordable 0 1 0 0 on 1.5 16
	[ "$status" -ne 0 ]
	run testrun_recordable 0 0 1 0 on 1.5 16
	[ "$status" -ne 0 ]
	run testrun_recordable 0 0 0 1 on 1.5 16
	[ "$status" -ne 0 ]
	run testrun_recordable 0 0 0 0 off 1.5 16
	[ "$status" -ne 0 ]
	run testrun_recordable 0 0 0 0 on 9.2 16
	[ "$status" -ne 0 ]
	[[ $output == *busy* ]]
}

@test "more than 15% foreign load during the run keeps it out of the worker history" {
	run testrun_recordable 0 0 0 0 on 1.5 16 12.4
	[ "$status" -eq 0 ]
	run testrun_recordable 0 0 0 0 on 1.5 16 15.1
	[ "$status" -ne 0 ]
	[[ $output == *"15.1% foreign load"* ]]
	# No samples (a run too short to take one) leaves the rule out.
	run testrun_recordable 0 0 0 0 on 1.5 16 ''
	[ "$status" -eq 0 ]
}

@test "a sample counts only the processes outside the run's tree, as a share of all CPUs" {
	# 100 = the run, 101 its worker, 102 a bats below it; 200 and 300 are foreign.
	ps() { printf '%s\n' '50.0 100 1' '300.0 101 100' '100.0 102 101' '40.0 200 1' '40.0 300 200'; }
	run testrun_foreign_cpu 100 8
	[ "$output" = 10.0 ]
	printf '%s\n' 10.0 20.0 x >"$BATS_TEST_TMPDIR/samples"
	run testrun_foreign_average "$BATS_TEST_TMPDIR/samples"
	[ "$output" = 15.0 ]
	run testrun_foreign_average "$BATS_TEST_TMPDIR/none"
	[ -z "$output" ]
}

@test "the impact map adds the suites that started a changed command or loaded a changed library" {
	mini_repo
	# other.bats reaches Cmd-One and lib foo through a computed name: no static reference.
	printf 'Unix/tests/other.bats\tcommand\tCmd-One\nUnix/tests/other.bats\tlib\tfoo\n' >"$BATS_TEST_TMPDIR/impact"
	printf 'M\tUnix/modules/A/bin/Cmd-One\n' >"$BATS_TEST_TMPDIR/changes"
	run testrun_select "$corpus" "$BATS_TEST_TMPDIR/changes" "$BATS_TEST_TMPDIR/impact"
	[[ $output == *$'Unix/tests/other.bats\tUnix/modules/A/bin/Cmd-One (impact map)'* ]]
	printf 'M\tUnix/lib/foo.sh\n' >"$BATS_TEST_TMPDIR/changes"
	run testrun_select "$corpus" "$BATS_TEST_TMPDIR/changes" "$BATS_TEST_TMPDIR/impact"
	[[ $output == *"Unix/tests/other.bats"* ]]
	# Without the map the static selection alone stands.
	run testrun_select "$corpus" "$BATS_TEST_TMPDIR/changes"
	[[ $output != *"other.bats"* ]]
}

@test "the impact map merge replaces the lines of the suites that ran and keeps the others" {
	map=$BATS_TEST_TMPDIR/map
	printf 'a.bats\tcommand\tOld\nb.bats\tcommand\tKept\n' >"$map"
	printf 'a.bats\tcommand\tNew\na.bats\tlib\tconfig\na.bats\tcommand\tNew\n\tcommand\tNoSuite\n' >"$BATS_TEST_TMPDIR/raw"
	testrun_impact_merge "$map" "$BATS_TEST_TMPDIR/raw" a.bats
	[ "$(cat "$map")" = "$(printf 'a.bats\tcommand\tNew\na.bats\tlib\tconfig\nb.bats\tcommand\tKept')" ]
}

@test "with FOUNDATION_IMPACT_LOG set a command records its start and every library it loads" {
	log=$BATS_TEST_TMPDIR/impact.raw
	FOUNDATION_IMPACT_LOG=$log FOUNDATION_IMPACT_SUITE=Unix/tests/x.bats FOUNDATION_LOGGING=off \
		"${BASH:-bash}" "$UNIX_DIR/modules/Helper/bin/Find-Item" --help >/dev/null
	grep -qx $'Unix/tests/x.bats\tcommand\tFind-Item' "$log"
	FOUNDATION_IMPACT_LOG=$log FOUNDATION_IMPACT_SUITE=Unix/tests/x.bats foundation_load config
	grep -qx $'Unix/tests/x.bats\tlib\tconfig' "$log"
}

@test "a changed command selects its suite, its callers' suites and the suites of workspaces naming it" {
	mini_repo
	run picked $'M\tUnix/modules/A/bin/Cmd-One'
	[ "$output" = "$(printf '%s\n' Unix/tests/modules/A/Cmd-One.bats Unix/tests/modules/A/Cmd-Two.bats Unix/tests/modules/B/Open-Workspace.bats)" ]
}

@test "a name only in a comment is no dependency" {
	mini_repo
	run picked $'M\tUnix/modules/A/bin/Cmd-One'
	[[ $output != *other.bats* ]]
}

@test "a changed library selects the commands loading it, transitively" {
	mini_repo
	run picked $'M\tUnix/lib/foo.sh'
	[ "$output" = "$(printf '%s\n' Unix/tests/modules/A/Cmd-One.bats Unix/tests/modules/A/Cmd-Two.bats Unix/tests/modules/B/Open-Workspace.bats)" ]
}

@test "a library every suite loads through the helper selects every suite; foundation.sh selects everything" {
	mini_repo
	run picked $'M\tUnix/lib/config.sh'
	[ "$(grep -c . <<<"$output")" -eq 5 ]
	run picked $'M\tUnix/lib/foundation.sh'
	[ "$output" = '*' ]
}

@test "a changed suite selects only itself; a deleted one nothing" {
	mini_repo
	run picked $'M\tUnix/tests/modules/A/Cmd-Two.bats'
	[ "$output" = Unix/tests/modules/A/Cmd-Two.bats ]
	run picked $'D\tUnix/tests/modules/A/Gone.bats'
	[ "$output" = Unix/tests/commands.bats ]
}

@test "an added command also selects the completeness check" {
	mini_repo
	run picked $'A\tUnix/modules/A/bin/Cmd-Three'
	[[ $output == *Unix/tests/commands.bats* ]]
}

@test "a file outside Unix selects the suites that read its folder" {
	mini_repo
	run picked $'M\tdocs/foundation/modules/A.md'
	[ "$output" = Unix/tests/commands.bats ]
	run picked $'M\tWindows/PowerShell/Profile.ps1'
	[ -z "$output" ]
}

@test "the selection keeps the first reason per suite, and everything wins" {
	run testrun_selection_unique <<<$'a.bats\tfirst\nb.bats\tx\na.bats\tsecond'
	[ "$output" = $'a.bats\tfirst\nb.bats\tx' ]
	run testrun_selection_unique <<<$'a.bats\tfirst\n*\tfoundation.sh'
	[ "$output" = $'*\tfoundation.sh' ]
}

@test "the lint runs for a changed shell file under Unix only" {
	printf 'M\tUnix/lib/foo.sh\n' >"$BATS_TEST_TMPDIR/c1"
	printf 'M\tUnix/modules/A/bin/Cmd-One\n' >"$BATS_TEST_TMPDIR/c2"
	printf 'M\tUnix/config/workspaces.conf\nM\tdocs/foundation/README.md\nM\tUnix/tests/fixtures/config/apps.conf\n' >"$BATS_TEST_TMPDIR/c3"
	testrun_needs_lint "$BATS_TEST_TMPDIR/c1"
	testrun_needs_lint "$BATS_TEST_TMPDIR/c2"
	run testrun_needs_lint "$BATS_TEST_TMPDIR/c3"
	[ "$status" -ne 0 ]
}

@test "the lint files: libraries, functions.sh, the shell rc files and every bash or sh command, nothing else" {
	repo=$BATS_TEST_TMPDIR/lint
	mkdir -p "$repo"/Unix/{lib/drivers,shell,modules/A/bin,modules/Custom/C/bin,tests}
	cd "$repo" || return 1
	: >Unix/lib/foo.sh
	: >Unix/lib/drivers/bar.sh
	: >Unix/bootstrap.sh
	: >Unix/modules/A/functions.sh
	: >Unix/shell/shellrc.sh
	: >Unix/shell/bashrc
	: >Unix/shell/zshrc
	printf '#!/usr/bin/env bash\n' >Unix/modules/A/bin/Cmd-Bash
	printf '#!/bin/sh\n' >Unix/modules/A/bin/cmd-sh
	printf '#!/usr/bin/env python3\n' >Unix/modules/A/bin/cmd-py
	: >Unix/modules/A/bin/empty
	printf '#!/usr/bin/env bash\n' >Unix/modules/Custom/C/bin/Custom-Cmd
	printf '#!/usr/bin/env bats\n' >Unix/tests/x.bats
	run testrun_lint_files
	[ "$status" -eq 0 ]
	[ "$(printf '%s\n' "$output" | LC_ALL=C sort | tr '\n' ' ')" = "Unix/bootstrap.sh Unix/lib/drivers/bar.sh Unix/lib/foo.sh Unix/modules/A/bin/Cmd-Bash Unix/modules/A/bin/cmd-sh Unix/modules/A/functions.sh Unix/modules/Custom/C/bin/Custom-Cmd Unix/shell/bashrc Unix/shell/shellrc.sh " ]
}

@test "misses are the failing suites the selection left out; everything misses nothing" {
	printf 'a.bats\nb.bats\n' >"$BATS_TEST_TMPDIR/failed"
	printf 'a.bats\n' >"$BATS_TEST_TMPDIR/picked"
	run testrun_misses "$BATS_TEST_TMPDIR/picked" "$BATS_TEST_TMPDIR/failed"
	[ "$output" = b.bats ]
	printf '*\n' >"$BATS_TEST_TMPDIR/picked"
	run testrun_misses "$BATS_TEST_TMPDIR/picked" "$BATS_TEST_TMPDIR/failed"
	[ -z "$output" ]
}

@test "the worker history keeps this machine's well-formed lines only" {
	history=$BATS_TEST_TMPDIR/history
	printf 'Mac/8/AC\t6\t30.5\t2026-10-01T10:00:00\tDefault\n' >"$history"
	printf 'Mac/8/Battery\t4\t40.0\t2026-10-01T11:00:00\tDefault\n' >>"$history"
	printf 'Mac/8/AC\tsix\t30.0\tx\tx\nMac/8/AC\t6x\t30.0\tx\tx\nMac/8/AC\t6\t\tx\tx\nMac/8/AC\t0\t20.0\tx\tx\ngarbage\n' >>"$history"
	printf 'Mac/8/AC\t8\t28\t2026-10-02T10:00:00\tExplore\n' >>"$history"
	run testrun_history_runs "$history" Mac/8/AC
	[ "$output" = $'6\t30.5\n8\t28' ]
	run testrun_history_runs "$history" Other/4/AC
	[ -z "$output" ]
	run testrun_history_runs "$BATS_TEST_TMPDIR/none" Mac/8/AC
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "the machine key changes with the power source, so learning restarts" {
	stub_tool sysctl 'case "$2" in hw.model) echo Mac1 ;; hw.ncpu) echo 8 ;; *) exit 1 ;; esac'
	stub_tool pmset "echo \"Now drawing from 'AC Power'\""
	[ "$(testrun_machine)" = Mac1/8/AC ]
	stub_tool pmset "echo \"Now drawing from 'Battery Power'\""
	[ "$(testrun_machine)" = Mac1/8/Battery ]
}

@test "conditions no probe can read are unknown, not zero, and an unknown load refuses nothing" {
	for tool in pmset sysctl uptime; do stub_tool "$tool" 'exit 1'; done
	[ "$(testrun_load)" = unknown ]
	[ "$(testrun_conditions)" = 'load unknown' ]
	run testrun_recordable 0 0 0 0 on unknown 8
	[ "$status" -eq 0 ]
	stub_tool sysctl 'echo "{ 7.50 6.00 5.00 }"'
	[ "$(testrun_load)" = 7.50 ]
	run testrun_recordable 0 0 0 0 on "$(testrun_load)" 8
	[ "$status" -ne 0 ]
}

@test "the queue: never-measured suites first, then the slowest first, equal times by name" {
	printf 'a.bats\t100\nb.bats\t5000\nc.bats\t100\nd.bats\tbroken\n' >"$BATS_TEST_TMPDIR/timings"
	run testrun_queue_order "$BATS_TEST_TMPDIR/timings" <<<$'a.bats\nc.bats\nnew.bats\nb.bats\nd.bats'
	[ "$output" = $'d.bats\nnew.bats\nb.bats\na.bats\nc.bats' ]
	run testrun_queue_order "$BATS_TEST_TMPDIR/none" <<<$'b.bats\na.bats'
	[ "$output" = $'a.bats\nb.bats' ]
}

@test "bats below the required version stops the run, a newer major warns" {
	[[ $(cat "$UNIX_DIR/tests/required-bats-version") =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
	[ "$(testrun_bats_verdict 1.13.9 1.14.0)" = old ]
	[ "$(testrun_bats_verdict 1.9.0 1.14.0)" = old ]
	[ "$(testrun_bats_verdict 1.14.0 1.14.0)" = ok ]
	[ "$(testrun_bats_verdict 1.20.1 1.14.0)" = ok ]
	[ "$(testrun_bats_verdict 2.0.0 1.14.0)" = newer-major ]
	[ "$(testrun_bats_verdict '' 1.14.0)" = unknown ]
	[ "$(testrun_bats_verdict 1.0.0 '')" = ok ]
	stub_tool bats 'echo "Bats 1.14.0"'
	[ "$(testrun_bats_version)" = 1.14.0 ]
}

@test "a file under Unix that nothing references runs everything; data, prose and other halves do not" {
	mini_repo
	run picked $'M\tUnix/home/dot_zshrc.tmpl'
	[ "$output" = '*' ]
	printf 'M\tUnix/home/dot_zshrc.tmpl\n' >"$BATS_TEST_TMPDIR/changes"
	run testrun_select "$corpus" "$BATS_TEST_TMPDIR/changes"
	[[ $output == *"no suite or code under Unix references it"* ]]
	run picked $'M\tUnix/config/workspaces.local.conf'
	[ -z "$output" ]
	run picked $'M\tUnix/modules/Custom/README.md'
	[ -z "$output" ]
	run picked $'M\tUnix/logs/Errors.log'
	[ -z "$output" ]
	run picked $'D\tUnix/tests/other.bats'
	[ -z "$output" ]
}

@test "a config file selects the suites reading Unix/config, a base file the contract too; a manifest its module's suites and the manifest gates" {
	mini_repo
	run picked $'M\tUnix/config/workspaces.conf'
	[ "$output" = Unix/tests/contract.bats ]
	# A suite that reads the committed config (written through %s, so this file reads none).
	printf 'load helpers\n@test "base" { cp "$%s"/config/*.conf "$BATS_TEST_TMPDIR"; }\n' UNIX_DIR >Unix/tests/base.bats
	testrun_corpus "$corpus"
	run picked $'M\tUnix/config/workspaces.conf'
	[ "$output" = "$(printf '%s\n' Unix/tests/base.bats Unix/tests/contract.bats)" ]
	run picked $'M\tUnix/config/workspaces.local.conf'
	[ "$output" = Unix/tests/base.bats ]
	run picked $'M\tUnix/config/layouts/Test/Default_Test.conf'
	[ "$output" = Unix/tests/base.bats ]
	run picked $'M\tUnix/modules/A/module.conf'
	[ "$output" = "$(printf '%s\n' Unix/tests/commands.bats Unix/tests/guides.bats Unix/tests/modules/A/Cmd-One.bats Unix/tests/modules/A/Cmd-Two.bats)" ]
}

@test "patterns pick suites by their path below Unix/tests, case-insensitively, several as a union" {
	suites=$'/r/Unix/tests/layout.bats\n/r/Unix/tests/modules/Application/Open-Obsidian.bats\n/r/Unix/tests/modules/Git/GitPull.bats\n/r/Unix/tests/obsidian.bats'
	run testrun_match_patterns obsidian <<<"$suites"
	[ "$output" = $'/r/Unix/tests/modules/Application/Open-Obsidian.bats\n/r/Unix/tests/obsidian.bats' ]
	run testrun_match_patterns application LAYOUT <<<"$suites"
	[ "$output" = $'/r/Unix/tests/layout.bats\n/r/Unix/tests/modules/Application/Open-Obsidian.bats' ]
	run testrun_match_patterns nothing-like-it <<<"$suites"
	[ -z "$output" ]
}

@test "a suite's own subject: the suite, its command or its library changed, not a deletion" {
	printf 'M\tUnix/modules/Git/bin/GitPull\nA\tUnix/tests/modules/Git/GitPush.bats\nM\tUnix/lib/layout.sh\nD\tUnix/tests/modules/Git/Gone.bats\n' >"$BATS_TEST_TMPDIR/changes"
	testrun_own_subject Unix/tests/modules/Git/GitPull.bats "$BATS_TEST_TMPDIR/changes"
	testrun_own_subject Unix/tests/modules/Git/GitPush.bats "$BATS_TEST_TMPDIR/changes"
	testrun_own_subject Unix/tests/layout.bats "$BATS_TEST_TMPDIR/changes"
	run testrun_own_subject Unix/tests/modules/Git/GitStatus.bats "$BATS_TEST_TMPDIR/changes"
	[ "$status" -ne 0 ]
	run testrun_own_subject Unix/tests/modules/Git/Gone.bats "$BATS_TEST_TMPDIR/changes"
	[ "$status" -ne 0 ]
}

@test "the selection preview shows each suite with its reason, at most MAX lines" {
	printf 'a.bats\tUnix/lib/x.sh\nb.bats\tUnix/lib/x.sh via y\nc.bats\tz\n' >"$BATS_TEST_TMPDIR/reasons"
	run testrun_selection_preview "$BATS_TEST_TMPDIR/reasons" 2
	[ "$output" = $'a.bats  <=  Unix/lib/x.sh\nb.bats  <=  Unix/lib/x.sh via y\n... and 1 more - see the run log' ]
	printf '*\tUnix/lib/foundation.sh (every command and suite sources it)\n' >"$BATS_TEST_TMPDIR/reasons"
	run testrun_selection_preview "$BATS_TEST_TMPDIR/reasons"
	[ "$output" = 'everything  <=  Unix/lib/foundation.sh (every command and suite sources it)' ]
}

@test "results retention keeps the ten newest run logs, removes older ones only a day old, and abandoned scratch folders" {
	results=$BATS_TEST_TMPDIR/results
	tmp=$BATS_TEST_TMPDIR/tmp
	mkdir -p "$results" "$tmp/foundation-tests.old" "$tmp/foundation-tests.new" "$tmp/other.old"
	for i in $(seq -w 1 13); do : >"$results/TestRun_202601${i}_000000_1.log"; done
	: >"$results/last-green"
	: >"$results/suite-timings.tsv"
	# 01-03 are old and beyond the ten newest; 13 is old but among them, so it stays.
	touch -t 202001010000 "$results"/TestRun_2026010[1-3]_000000_1.log "$results/TestRun_20260113_000000_1.log" "$results/last-green" "$results/suite-timings.tsv" "$tmp/foundation-tests.old" "$tmp/other.old"
	run testrun_prune_results "$results" "$tmp"
	[ "$status" -eq 0 ]
	[ "$output" = $'removed TestRun_20260103_000000_1.log\nremoved TestRun_20260102_000000_1.log\nremoved TestRun_20260101_000000_1.log\nremoved foundation-tests.old' ]
	logs=("$results"/TestRun_*.log)
	[ ${#logs[@]} -eq 10 ]
	[ -f "$results/TestRun_20260113_000000_1.log" ]
	[ -f "$results/last-green" ]
	[ -f "$results/suite-timings.tsv" ]
	[ -d "$tmp/foundation-tests.new" ]
	[ -d "$tmp/other.old" ]
	# Fewer than eleven run logs: nothing goes, however old.
	rm "$results"/TestRun_2026011*_000000_1.log
	touch -t 202001010000 "$results"/TestRun_*.log
	run testrun_prune_results "$results"
	[ -z "$output" ]
}
