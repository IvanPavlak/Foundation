#!/usr/bin/env bats
# Infrastructure-Contract analog: no command, documented flag, line kind of a shipped base
# Unix/config file or Bootstrap step of the last release's baseline (contract-baseline.tsv) is gone
# without a shipped deprecation, and every release's version bump matches its changelog sections.
# Both skip until Foundation cuts 1.0.0 (a baseline and its CHANGELOG.md): no rules apply in 0.x, as in
# WinuX before its 1.0.0. The checker itself is pinned on a miniature tree and changelog fixtures.

load helpers

setup() {
	setup_foundation
	foundation_load testrun
	ROOT=$(dirname "$UNIX_DIR")
	BASELINE=$UNIX_DIR/tests/contract-baseline.tsv
}

# A miniature Unix/ under $BATS_TEST_TMPDIR/unix: module A with a documented command, a helper and
# an undocumented executable, a Custom module, base and overlay config files, a Bootstrap catalog.
mini_unix() {
	unix=$BATS_TEST_TMPDIR/unix
	mkdir -p "$unix"/modules/{A,Bootstrap,Custom/C}/bin "$unix/config"
	printf 'description A\ncommand Cmd-One\nhelper cmd-helper\n' >"$unix/modules/A/module.conf"
	printf '#!/usr/bin/env bash\n# Cmd-One - does one thing.\n#\n# Usage: Cmd-One [--alpha] [--beta N]\necho\n' >"$unix/modules/A/bin/Cmd-One"
	printf '#!/bin/sh\n# cmd-helper --hidden\n' >"$unix/modules/A/bin/cmd-helper"
	printf 'command Bootstrap\n' >"$unix/modules/Bootstrap/module.conf"
	printf '#!/usr/bin/env bash\n# Bootstrap - steps.\nCATALOG=(\n\t"Homebrew on"\n\t"Dotfiles off sudo"\n)\n' >"$unix/modules/Bootstrap/bin/Bootstrap"
	printf 'command Fork-Only\n' >"$unix/modules/Custom/C/module.conf"
	printf '#!/usr/bin/env bash\n# Fork-Only - mine.\n' >"$unix/modules/Custom/C/bin/Fork-Only"
	printf '# comment\nmax-age-days 7\n@Work,Test   step Docker on\n\n[Section]\nindex / on\nDotfiles /x.git $HOME\n' >"$unix/config/sample.conf"
	printf 'Zero Fullscreen:100\nalias Full Zero\n' >"$unix/config/zones.conf"
	printf 'private-kind on\n' >"$unix/config/sample.local.conf"
}

@test "no part of the last release's contract is gone without a shipped deprecation" {
	[ -f "$BASELINE" ] || skip "no contract baseline yet: Run-Tests --update-contract-baseline writes it when Foundation cuts 1.0.0 (no rules apply in 0.x)"
	testrun_contract_snapshot "$UNIX_DIR" >"$BATS_TEST_TMPDIR/snapshot"
	changelog=$(testrun_changelog_path "$ROOT") || changelog=''
	run testrun_contract_violations "$BASELINE" "$BATS_TEST_TMPDIR/snapshot" "$changelog"
	[ -z "$output" ] || {
		printf '%s\n' "$output"
		return 1
	}
}

@test "every release's version bump matches its changelog sections" {
	changelog=$(testrun_changelog_path "$ROOT") || skip "no Foundation CHANGELOG.md (in Dotfiles the root one is WinuX's)"
	run testrun_version_bumps "$changelog"
	[ -z "$output" ] || {
		printf '%s\n' "$output"
		return 1
	}
}

@test "the snapshot: manifest commands and their flags, base line kinds and sections, Bootstrap steps" {
	mini_unix
	run testrun_contract_snapshot "$unix"
	[ "$status" -eq 0 ]
	expected=$(printf '%s\n' \
		$'command\tBootstrap' $'command\tCmd-One' $'flag\tCmd-One --alpha' $'flag\tCmd-One --beta' \
		$'key\tsample.conf [Section]' $'key\tsample.conf [Section] index' $'key\tsample.conf max-age-days' \
		$'key\tsample.conf step' $'key\tzones.conf alias' $'step\tBootstrap Dotfiles' $'step\tBootstrap Homebrew' | LC_ALL=C sort)
	[ "$output" = "$expected" ]
}

@test "a removal is a violation; an addition is not; a removed command's flags are its own violation" {
	mini_unix
	testrun_contract_snapshot "$unix" >"$BATS_TEST_TMPDIR/before"
	{
		printf 'version\t1.0.0\n'
		cat "$BATS_TEST_TMPDIR/before"
		printf 'command\tGone\nflag\tGone --x\n'
	} >"$BATS_TEST_TMPDIR/baseline"
	sed -i.bak 's/ \[--beta N\]/ [--gamma]/' "$unix/modules/A/bin/Cmd-One"
	sed -i.bak '/^max-age-days/d' "$unix/config/sample.conf"
	sed -i.bak '/Dotfiles off/d' "$unix/modules/Bootstrap/bin/Bootstrap"
	testrun_contract_snapshot "$unix" >"$BATS_TEST_TMPDIR/after"
	run testrun_contract_violations "$BATS_TEST_TMPDIR/baseline" "$BATS_TEST_TMPDIR/after"
	[ "${#lines[@]}" -eq 4 ]
	[[ ${lines[0]} == "Command [Gone] was removed."* ]]
	[[ ${lines[1]} == "Config line [sample.conf max-age-days] is no longer in the shipped base file."* ]]
	[[ ${lines[2]} == "Flag [--beta] of [Cmd-One] was removed or renamed."* ]]
	[[ ${lines[3]} == "Step [Bootstrap Dotfiles] was removed."* ]]
	[[ $output != *gamma* ]]
}

@test "a removal is sanctioned by ### Breaking, or by ### Removed after a deprecation that shipped" {
	printf 'version\t1.2.0\ncommand\tA\ncommand\tB\ncommand\tC\ncommand\tD\n' >"$BATS_TEST_TMPDIR/baseline"
	printf 'deprecated\tcommand\tB\t1.1.0\ndeprecated\tcommand\tC\t1.3.0\n' >>"$BATS_TEST_TMPDIR/baseline"
	: >"$BATS_TEST_TMPDIR/now"
	cat >"$BATS_TEST_TMPDIR/CHANGELOG.md" <<'MD'
# Changelog

## [Unreleased]

### Breaking

- `A` is gone at once.

### Removed

- `B` and `C` (deprecated earlier).

## [1.2.0] - 2026-10-01

### Removed

- `D` is named only in a released section.

[Unreleased]: https://example.invalid/compare/v1.2.0...HEAD
MD
	run testrun_contract_violations "$BATS_TEST_TMPDIR/baseline" "$BATS_TEST_TMPDIR/now" "$BATS_TEST_TMPDIR/CHANGELOG.md"
	# B's deprecation shipped (1.1.0 <= 1.2.0); C's has not (1.3.0); D is not in [Unreleased].
	[ "$output" = "$(printf '%s\n' 'Command [C] was removed. Keep it working and deprecate it first (VERSIONING.md, Deprecation policy); it can be removed in the next MAJOR.' 'Command [D] was removed. Keep it working and deprecate it first (VERSIONING.md, Deprecation policy); it can be removed in the next MAJOR.')" ]
}

@test "the baseline keeps the deprecation records that still apply and drops the ones this release removed" {
	printf 'command\tKept\n' >"$BATS_TEST_TMPDIR/snapshot"
	printf 'version\t1.0.0\ncommand\tKept\ncommand\tRemoved\n' >"$BATS_TEST_TMPDIR/previous"
	printf 'deprecated\tcommand\tKept\t1.0.0\ndeprecated\tcommand\tRemoved\t0.9.0\ndeprecated\tkey\tx.conf unseen\t1.0.0\n' >>"$BATS_TEST_TMPDIR/previous"
	run testrun_contract_baseline "$BATS_TEST_TMPDIR/snapshot" 2.0.0 "$BATS_TEST_TMPDIR/previous"
	[ "$status" -eq 0 ]
	body=$(printf '%s\n' "$output" | grep -v '^#')
	[ "$body" = "$(printf 'version\t2.0.0\ncommand\tKept\ndeprecated\tcommand\tKept\t1.0.0\ndeprecated\tkey\tx.conf unseen\t1.0.0')" ]
	run testrun_contract_baseline "$BATS_TEST_TMPDIR/snapshot" 0.1.0
	[ "$(printf '%s\n' "$output" | grep -v '^#')" = "$(printf 'version\t0.1.0\ncommand\tKept')" ]
}

@test "the changelog readers: releases newest first with their subsections, one [Unreleased] subsection" {
	cat >"$BATS_TEST_TMPDIR/CHANGELOG.md" <<'MD'
## [Unreleased]
### Removed
- `X`
## [1.1.0-rc.1] - 2026-10-02
### Added
### Deprecated
## [1.0.0] - 2026-10-01
### Fixed
[1.0.0]: https://example.invalid
### Ignored
MD
	run testrun_changelog_releases "$BATS_TEST_TMPDIR/CHANGELOG.md"
	[ "$output" = $'1.1.0-rc.1\tAdded,Deprecated\n1.0.0\tFixed' ]
	run testrun_changelog_unreleased "$BATS_TEST_TMPDIR/CHANGELOG.md" Removed
	[ "$output" = '- `X`' ]
	run testrun_changelog_unreleased "$BATS_TEST_TMPDIR/CHANGELOG.md" Breaking
	[ -z "$output" ]
}

@test "version bumps: the VERSIONING ladder from 1.0.0 on, the 0.x series exempt" {
	cat >"$BATS_TEST_TMPDIR/CHANGELOG.md" <<'MD'
## [Unreleased]
## [3.1.0] - 2026-10-09
### Removed
## [3.0.1] - 2026-10-08
### Added
## [3.0.0] - 2026-10-07
### Fixed
## [2.1.1] - 2026-10-06
### Added
## [2.0.0] - 2026-10-05
### Breaking
## [1.0.0] - 2026-10-04
### Fixed
## [1.0.0] - 2026-10-03
### Fixed
## [0.9.0] - 2026-10-02
### Removed
## [0.1.0] - 2026-10-01
### Added
MD
	run testrun_version_bumps "$BATS_TEST_TMPDIR/CHANGELOG.md"
	[[ ${lines[0]} == "[3.1.0] removes or breaks part of the contract"* ]]
	[[ ${lines[1]} == "[3.0.1] adds, changes or deprecates something"* ]]
	[[ ${lines[2]} == "[3.0.0] is a MAJOR release but removes and breaks nothing"* ]]
	[[ ${lines[3]} == "[2.1.1] is a MINOR release, so its PATCH must be 0." ]]
	[[ ${lines[4]} == "[1.0.0] is not higher than the release before it, [1.0.0]." ]]
	# 2.0.0 after 1.0.0 is a clean MAJOR; 1.0.0 after 0.9.0 and 0.9.0 after 0.1.0 are exempt.
	[ "${#lines[@]}" -eq 5 ]
}

@test "the changelog is Foundation's: FOUNDATION_CHANGELOG, else the root one outside Dotfiles" {
	repo=$BATS_TEST_TMPDIR/repo
	mkdir -p "$repo"
	printf '## [Unreleased]\n' >"$repo/CHANGELOG.md"
	run testrun_changelog_path "$repo"
	[ "$output" = "$repo/CHANGELOG.md" ]
	mkdir -p "$repo/Windows/PowerShell"
	run testrun_changelog_path "$repo"
	[ "$status" -ne 0 ]
	printf '## [Unreleased]\n' >"$BATS_TEST_TMPDIR/draft.md"
	FOUNDATION_CHANGELOG=$BATS_TEST_TMPDIR/draft.md run testrun_changelog_path "$repo"
	[ "$output" = "$BATS_TEST_TMPDIR/draft.md" ]
	FOUNDATION_CHANGELOG=$BATS_TEST_TMPDIR/missing.md run testrun_changelog_path "$repo"
	[ "$status" -ne 0 ]
}
