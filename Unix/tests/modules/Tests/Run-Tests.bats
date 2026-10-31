#!/usr/bin/env bats
# Run-Tests: a pattern picks suites by path, --filter narrows the tests, --quick leaves out the
# integration tier, --shard runs a slice, the flag rules of --changed, --audit-since,
# --update-contract-baseline, --update-suite-weights and --lint-files (the shellcheck list CI
# reads), the verdict line and the run log (conditions, workers, per-test times) name what ran.
# Run against one test of one small suite (--filter "$one") with the lint off, so it never
# recurses into the whole suite and each nested run stays short.

# bats file_tags=integration
load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_LOGGING=off
	cmd=$UNIX_DIR/modules/Tests/bin/Run-Tests
	one='^title: empty pattern matches anything$'
}

@test "a pattern runs only the matching suite and reports its count" {
	run "${BASH:-bash}" "$cmd" match.bats --no-lint --filter "$one"
	[ "$status" -eq 0 ]
	[[ $output == *"Running 1 test file(s) across 1 worker(s)"* ]]
	[[ $output == *"All tests passed! (1 passed in "*"s across 1 worker)"* ]]
	[[ $output != *shellcheck* ]]
	log=$(printf '%s\n' "$output" | sed -n 's/.*Log file location => //p')
	grep -q '^== bats Unix/tests/match.bats (exit 0, ' "$DOTFILES_ROOT/$log"
}

@test "the run log opens with the run conditions and holds every test's time" {
	run "${BASH:-bash}" "$cmd" match.bats --no-lint --filter "$one"
	[ "$status" -eq 0 ]
	log=$DOTFILES_ROOT/$(printf '%s\n' "$output" | sed -n 's/.*Log file location => //p')
	grep -qxF "Mode: pattern: match.bats, filter: $one" "$log"
	grep -q '^Machine: ' "$log"
	grep -q '^Conditions: .*load ' "$log"
	grep -q '^Workers: 1 (Scoped - ' "$log"
	grep -q '^Worker history: not recorded: scoped run$' "$log"
	grep -q '^Slowest tests:$' "$log"
	grep -qE '^ok 1 .* in [0-9]+ms$' "$log"
}

@test "started with SIGPIPE ignored, it runs the suites with it at the default and says so in the run log" {
	command -v perl >/dev/null 2>&1 || skip "perl is required"
	run perl -e '$SIG{PIPE} = "IGNORE"; exec { $ARGV[0] } @ARGV' "${BASH:-bash}" "$cmd" match.bats --no-lint --filter "$one"
	[ "$status" -eq 0 ]
	log=$DOTFILES_ROOT/$(printf '%s\n' "$output" | sed -n 's/.*Log file location => //p')
	grep -qxF 'SIGPIPE: started ignored, reset to the default for the suites' "$log"
	# Without the ignore there is nothing to reset.
	run "${BASH:-bash}" "$cmd" match.bats --no-lint --filter "$one"
	log=$DOTFILES_ROOT/$(printf '%s\n' "$output" | sed -n 's/.*Log file location => //p')
	! grep -q '^SIGPIPE: ' "$log" || false
}

@test "--quick leaves out the integration suites" {
	run "${BASH:-bash}" "$cmd" GitPull --quick --no-lint
	[ "$status" -eq 0 ]
	[[ $output == *"Every selected suite is in the integration tier (1 left out by --quick)"* ]]
	[[ $output != *"Running "* ]]
}

@test "--changed with a pattern is a union, not an error" {
	# A revision that cannot resolve stops the run before any suite starts.
	run "${BASH:-bash}" "$cmd" match.bats --changed --since no-such-revision-anywhere --no-lint
	[ "$status" -ne 0 ]
	[[ $output == *"Cannot find the merge base of [no-such-revision-anywhere]"* ]]
	[[ $output != *"cannot be combined"* ]]
}

@test "--update-contract-baseline runs no tests, combines with nothing and needs a released version" {
	run "${BASH:-bash}" "$cmd" --update-contract-baseline --quick
	[ "$status" -ne 0 ]
	[[ $output == *"cannot be combined with any other flag"* ]]
	printf '# Changelog\n\n## [Unreleased]\n' >"$BATS_TEST_TMPDIR/CHANGELOG.md"
	FOUNDATION_CHANGELOG=$BATS_TEST_TMPDIR/CHANGELOG.md run "${BASH:-bash}" "$cmd" --update-contract-baseline
	[ "$status" -ne 0 ]
	[[ $output == *"has no released version to stamp the baseline with"* ]]
	[[ $output != *"Running "* ]]
}

@test "--since and --audit-since take a revision; --audit-since only audits a full run" {
	run "${BASH:-bash}" "$cmd" --since
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" --audit-since
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" --audit-since master --quick
	[ "$status" -ne 0 ]
	[[ $output == *"--audit-since audits a full run"* ]]
}

@test "--filter narrows the run to the matching tests" {
	run "${BASH:-bash}" "$cmd" match.bats --no-lint --filter '^title: (empty|alternation)'
	[ "$status" -eq 0 ]
	[[ $output == *"All tests passed! (2 passed"* ]]
}

@test "--shard runs its slice of the selection and says so; a slice with no suite runs nothing" {
	run "${BASH:-bash}" "$cmd" match.bats --shard 1/2 --no-lint --filter "$one"
	[ "$status" -eq 0 ]
	[[ $output == *"Running 1 test file(s)"* ]]
	log=$DOTFILES_ROOT/$(printf '%s\n' "$output" | sed -n 's/.*Log file location => //p')
	grep -qxF "Mode: pattern: match.bats, shard 1/2: 1 of 1 suites, filter: $one" "$log"
	grep -q '^Worker history: not recorded: scoped run$' "$log"
	run "${BASH:-bash}" "$cmd" match.bats --shard 2/2 --no-lint
	[ "$status" -eq 0 ]
	[[ $output == *"Shard 2/2 holds no suite of the 1 selected - nothing to run."* ]]
	[[ $output != *"Running "* ]]
	run "${BASH:-bash}" "$cmd" match.bats --shard 3/2 --no-lint
	[ "$status" -ne 0 ]
	[[ $output == *"--shard takes I/N"* ]]
}

@test "--update-suite-weights writes the existing suites' last times by name, runs no tests and combines with nothing" {
	results=$BATS_TEST_TMPDIR/results
	mkdir -p "$results"
	printf 'Unix/tests/match.bats\t1200\nUnix/tests/gone.bats\t99\nUnix/tests/match.bats\t5\nUnix/tests/config.bats\t3400\n' >"$results/suite-timings.tsv"
	export FOUNDATION_TEST_RESULTS=$results FOUNDATION_SUITE_WEIGHTS=$BATS_TEST_TMPDIR/weights.tsv
	run "${BASH:-bash}" "$cmd" --update-suite-weights
	[ "$status" -eq 0 ]
	[[ $output == *"Suite weights => "*"(2 of "*" suites)"* ]]
	[ "$(cat "$FOUNDATION_SUITE_WEIGHTS")" = $'Unix/tests/config.bats\t3400\nUnix/tests/match.bats\t1200' ]
	run "${BASH:-bash}" "$cmd" --update-suite-weights --shard 1/2
	[ "$status" -ne 0 ]
	[[ $output == *"cannot be combined with any other flag"* ]]
	rm "$results/suite-timings.tsv"
	run "${BASH:-bash}" "$cmd" --update-suite-weights
	[ "$status" -ne 0 ]
	[[ $output == *"No suite times yet"* ]]
}

@test "--workers takes a number" {
	run "${BASH:-bash}" "$cmd" match.bats --no-lint --workers many
	[ "$status" -ne 0 ]
}

@test "an unmatched pattern fails" {
	run "${BASH:-bash}" "$cmd" no-such-suite-anywhere --no-lint
	[ "$status" -ne 0 ]
}

@test "--path narrows the selection to the suites below that folder of Unix/tests" {
	run "${BASH:-bash}" "$cmd" match.bats --path "$UNIX_DIR/tests/modules" --no-lint
	[ "$status" -ne 0 ]
	[[ $output == *"No test suite matches"* ]]
	run "${BASH:-bash}" "$cmd" --path "$UNIX_DIR/lib" --no-lint
	[ "$status" -ne 0 ]
	[[ $output == *"is not a folder of Unix/tests"* ]]
	run "${BASH:-bash}" "$cmd" -Path "$UNIX_DIR/tests" match.bats --no-lint --filter "$one"
	[ "$status" -eq 0 ]
	[[ $output == *"Running 1 test file(s)"* ]]
}

@test "an unknown flag is an error, never a pattern; the Windows -testname works in any case" {
	run "${BASH:-bash}" "$cmd" --no-lint -PassThru
	[ "$status" -ne 0 ]
	[[ $output == *"Unknown argument => --pass-thru"* ]]
	run "${BASH:-bash}" "$cmd" -testname match.bats --no-lint --filter "$one"
	[ "$status" -eq 0 ]
	[[ $output == *"Running 1 test file(s)"* ]]
}

@test "--lint-files prints the shellcheck list (the rc files and the sh commands too), runs nothing and combines with nothing" {
	run "${BASH:-bash}" "$cmd" --lint-files
	[ "$status" -eq 0 ]
	printf '%s\n' "$output" | grep -qx Unix/lib/foundation.sh
	printf '%s\n' "$output" | grep -qx Unix/shell/shellrc.sh
	printf '%s\n' "$output" | grep -qx Unix/shell/bash_profile
	printf '%s\n' "$output" | grep -qx Unix/modules/Tests/bin/Run-Tests
	printf '%s\n' "$output" | grep -qx Unix/modules/Git/bin/git-obsidian
	[[ $output != *.bats* ]]
	[[ $output != *Running* ]]
	run "${BASH:-bash}" "$cmd" --lint-files --quick
	[ "$status" -ne 0 ]
	[[ $output == *"cannot be combined with any other flag"* ]]
	run "${BASH:-bash}" "$cmd" --lint-files match.bats
	[ "$status" -ne 0 ]
}

@test "an early exit leaves no scratch folder behind" {
	mkdir -p "$BATS_TEST_TMPDIR/tmp"
	TMPDIR=$BATS_TEST_TMPDIR/tmp run "${BASH:-bash}" "$cmd" no-such-suite-anywhere --no-lint
	[ "$status" -ne 0 ]
	[ -z "$(ls -A "$BATS_TEST_TMPDIR/tmp")" ]
}
