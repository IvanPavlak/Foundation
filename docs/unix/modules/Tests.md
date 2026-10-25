<!-- reference: module unix Tests -->

# Tests

Runs the Unix test suites and the shellcheck lint.

Manifest: [`Unix/modules/Tests/module.conf`](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Tests/module.conf). One entry per command, alphabetical; the bullet block right under each heading is the parsed part.

## [Run-Tests](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Tests/bin/Run-Tests)

- **Description:** Runs the bats suites of `Unix/tests` in parallel workers and, without a pattern (or with `--lint`), shellcheck (`-S warning`) and the `shfmt` format check over the same files as the Unix CI workflow, alongside the suites (an unformatted file fails; `shfmt -w FILE` fixes it). The shellcheck list is the libraries and drivers, `bootstrap.sh`, every `functions.sh`, the shell rc files (`Unix/shell/shellrc.sh`, `bashrc`, `bash_profile`) and every command with a bash or `sh` shebang; `--lint-files` prints it, one path per line, runs nothing and combines with no other flag, and the CI workflow lints exactly that output, so the two lists cannot drift. The other lint settings live in files CI, `Run-Tests` and the editor extensions all read: `Unix/.shellcheckrc` (`external-sources=true`, the `-x` flag; the severity has no rc key, so it stays a flag) and `Unix/.editorconfig` (tabs, case branches indented: the `shfmt -ci` style, which shfmt reads only when no formatting flag is given). Suites live in `Unix/tests` (libraries) and `Unix/tests/modules/<Module>/<Command>.bats` (per command); PATTERN matches their path. PATTERN picks suites by file name (`Run-Tests layout`), several run the union; `--filter REGEX` narrows to matching test names; `--no-lint` skips the lint; `--workers N` sets the number of parallel bats processes (default: the CPU count, at most 12). `--quick` leaves out the integration tier (suites tagged `# bats file_tags=integration`: real git, real processes, real waits); `--changed` runs only the suites the changes since the merge base with `master` (plus uncommitted and untracked files) can affect, and the lint only when a shell file under `Unix/` changed (`--since REF` picks another base); with PATTERNs it runs the union of both (`-Changed` with `-TestName` on Windows), the selection is printed before the run (the first 40 suites, each with its reason; the whole list is in the run log), and under `--quick` a suite whose own file, command or library changed still runs even in the integration tier; `--audit-since REF` runs the full suite and then reports every failing suite `--changed` since REF would have left out (a warning annotation in CI, never a failure). After `--quick` or `--changed`, a reminder follows when this exact working tree has no green full run yet (`Unix/tests/Results/last-green`); a full run that fails on the tree a `--changed` run passed on names the suites that selection missed. Without `--workers` the count is learned per machine and power source from earlier clean full runs (`Unix/tests/Results/worker-history.tsv`: lowest median wall clock, neighbours of the best explored first, one re-checked every 20th run); without history it is the CPU count, at most 12, and a scoped run gives no worker less than about 2 s of work. Each worker takes the next suite off a shared queue, the slowest suites of the previous run first (`Unix/tests/Results/suite-timings.tsv`). Like the Windows `Run-Tests`, the terminal shows a spinner with a live `ran/expected tests` counter and elapsed seconds (in a terminal too narrow for the whole line, the `Running N test file(s)` part is left out so the counter and the timer stay visible), then the failures (the name in red, file and line, first line of the reason; a blank line between failures) and one verdict line; outside a terminal it prints one plain progress line instead of the spinner. The run log `Unix/tests/Results/TestRun_<timestamp>_<pid>.log` (gitignored) opens with the run conditions (mode, machine, power, Low Power Mode, load at start and end, workers and why, whether the run was recorded, the `--changed` selection with a reason per suite) and the ten slowest tests, then holds every suite's full TAP output with per-test times; `--detailed` also prints it. Each run first prunes `Unix/tests/Results` as the Windows harness does: the ten newest run logs stay, an older one goes once it is a day old, and so does a `foundation-tests.*` scratch folder a killed run left in `$TMPDIR`; the timings, history and last-green files are never touched (Invoke-LogMaintenance repeats it on its sweep). Exit status 1 when a test or the lint failed, 2 when a suite did not run cleanly. `--path DIR` (the Windows `-Path`) narrows every selection to the suites below that folder of `Unix/tests`. A flag it does not know is an error, never a pattern. `--build-impact-map` (the `-BuildImpactMap` of Windows) records, for every suite that runs, each Foundation command it started and each library it loaded (`lib/foundation.sh` logs them while `FOUNDATION_IMPACT_LOG` is set, so commands started by path count too) into `Unix/tests/Results/impact-map.tsv`, merged per suite; `--changed` then also picks the suites the map saw use a changed command or library, a dependency no name in the code shows. A run teaches the worker count only when processes outside it used at most 15% of the machine while it ran (sampled every 2 s with `ps`, the run's own process tree left out, as Windows' run-condition sampler); the average is in the run log's conditions line; a load no probe can read is logged as `unknown` (not zero) and refuses nothing, and a malformed line of the worker history is skipped. The suites need bats at least the version in `Unix/tests/required-bats-version` (the `RequiredPesterVersion.txt` of Windows; a minimum, since Homebrew installs only the newest `bats-core`): an older bats stops the run before any suite starts, a newer major warns. `--update-contract-baseline` (the release step, `-UpdateContractBaseline` on Windows) runs no tests and combines with no other flag: it rewrites `Unix/tests/contract-baseline.tsv` from the working tree, stamped with the newest release of Foundation's `CHANGELOG.md` (`FOUNDATION_CHANGELOG`, or the repository root's outside Dotfiles, whose root changelog is WinuX's), keeping the hand-written deprecation records that still apply.
- **Usage:** `Run-Tests [PATTERN...] [--path DIR] [--quick] [--changed] [--since REF] [--audit-since REF] [--lint] [--no-lint] [--filter REGEX] [--workers N] [--detailed] [--build-impact-map]`, `Run-Tests --update-contract-baseline`, `Run-Tests --lint-files` (the Windows-style `--test-name` is accepted and ignored)

Command suites run the real commands against stand-ins for the platform tools
(`Unix/tests/platform.bash`: `aerospace`, `wezterm`, `osascript`, `open`, `lsappinfo`, `pgrep`).
Every call is logged for the assertions, AeroSpace reports a fixture window list that `open -b`
extends and `close` shrinks, running apps get a pid that cannot exist, and the harness refuses to
start unless every tool resolves to its stand-in - so a suite never quits an app, moves a window
or closes a tab of the machine it runs on. A "not installed" case takes a tool away with `hide_tool
NAME` (`Unix/tests/helpers.bash`): it removes the stand-in, trims PATH to the stand-ins and the
system folders, and sets `FOUNDATION_NO_BREW_PATH=1`, which stops `lib/foundation.sh` from adding
`/opt/homebrew/bin` and `/usr/local/bin` back; it fails the test before anything runs if the tool
is still found, so the command can never reach the real `brew`, `mas`, `conda` or `dotnet`.

The suites never read `Unix/config` to get their values; only the checks of the committed files
themselves do (`contract.bats`, the contract below, and the suites that copy `$UNIX_DIR/config`).
`setup_foundation` points `FOUNDATION_CONFIG_DIR` at the generic
fixture config in `Unix/tests/fixtures/config` (placeholder workspaces, projects, browser groups
and layouts), `copy_fixture_config` gives a test a writable copy, and every assertion is about a
fixture value or a behaviour - so editing your own workspaces or layouts never breaks a test.
Whether the committed `Unix/config` is consistent is what `Test-ConfigurationSchema --strict`
checks.

How `--changed` decides (`Unix/lib/testrun.sh`, pinned by `Unix/tests/testrun.bats`): a changed
suite runs itself; a changed command selects every suite, command, library or fixture config
file that names it (full-line comments do not count); a changed library selects whatever loads it
by `foundation_load` or file name, and a test helper whatever `load`s it - transitively, so a library
that `helpers.bash` loads selects every suite, and `lib/foundation.sh` selects everything. A fixture
workspace naming a changed command selects the commands that read that file (`Open-Workspace`
runs the actions of `workspaces.conf`). Any other file selects the suites that reference its path
or a parent folder of it (`AI/Skills`, `docs/unix/modules`). A file that appeared or vanished also
selects the suites and commands that enumerate its folder (`modules/*/bin/*`) and the
completeness check. A module manifest (`module.conf`) selects that module's suites, `commands.bats`
and `guides.bats`; a file of `Unix/config` selects the suites that read `$UNIX_DIR/config`, and a
shipped base file also `contract.bats`. A changed file under `Unix/` that selects
nothing at all (a chezmoi template in `Unix/home`, a file of `Unix/shell` no suite names) runs
everything, as `Get-TestImpact` runs the full suite for a path no rule recognises; Markdown, the
logs, the results folder and a deleted suite are the exceptions. The full run stays the gate: CI
always runs everything.

The contract (`contract.bats`, the Infrastructure-Contract gate of Windows) binds from 1.0.0: no
rules apply in 0.x, as in WinuX before its 1.0.0, so the suite skips until the first baseline is
written when 1.0.0 is cut. At each release from then on
`Run-Tests --update-contract-baseline` records in `Unix/tests/contract-baseline.tsv` the commands of
the engine manifests, the long flags each documents in its header, the line kinds and sections of
the shipped base `Unix/config` files (the first word of a line when it is lowercase: `step`,
`max-age-days`; a capitalised first word is data) and the Bootstrap steps. From then on a later
change fails the suite when one of them is gone, unless the changelog's `[Unreleased]` section
sanctions it: a `### Breaking` subsection naming the item in backticks (`` `Kill-All --keep` ``,
`` `kill-all.conf step` ``, `` `Bootstrap Homebrew` ``), or a `### Removed` one naming an item whose
`deprecated<TAB>KIND<TAB>ITEM<TAB>VERSION` line (added to the baseline by hand when the deprecation
ships) is no later than the baseline's release. The same suite checks every release's version
bump against its changelog sections (VERSIONING.md, from 1.0.0 on). Both checks skip until
Foundation has its first release and its own `CHANGELOG.md`; the checker itself is pinned on
fixtures. Unix flags are all optional, so the Windows rule about a newly mandatory parameter has no
counterpart.

The documentation gates: `doclinks.bats` checks every link under `docs/unix` (the Foundation
sidebar `docs/unix/_sidebar.md` included), that the shared `docs/_sidebar.md` carries no Unix or
Decisions entry (it stays WinuX's) and that the fork-owned custom page links the Foundation docs;
`guides.bats` also checks that the Foundation sidebar lists every module page, every guide index
and `macos-configurator.md`; `List-Functions --list-discrepancies` (run by
`commands.bats`) also fails a module page whose entries are not alphabetical.

Coverage is enforced: `commands.bats` fails when a command has no
`tests/modules/<Module>/<Command>.bats`, so every command has its own suite (as every Windows
function has its Pester file) and a new command arrives with its test.

bats runs each test under errexit, which ignores a negated command and every command of an
`a && b` list but the last, so neither can fail a test unless it is the test's last line. A suite
writes a negated assertion as `! cmd || false` and puts one assertion on each line;
`commands.bats` fails on a `! cmd` line without the `|| false`.
