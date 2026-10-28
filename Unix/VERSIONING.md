# How Foundation Versions & Releases

## Versioning - Semantic Versioning 2.0.0

Foundation uses `MAJOR.MINOR.PATCH`. A dotfiles system has no classic API, so the contract is
what a fork depends on when it merges upstream:

- **the command set** - every `command` line of every engine `module.conf` and the flags each
  command's header documents (the Custom area is the fork's, not part of the contract);
- **the config line kinds** - every line kind of the shipped base files in `Unix/config`, the
  `@TYPE` and `-LINE` rules and the `.local.conf` overlay rules;
- **the Bootstrap steps** - every step of the `Bootstrap` catalogue and what `Unix/bootstrap.sh`
  does on a first run.

| Bump      | When |
| --------- | ---- |
| **MAJOR** | A change that breaks the contract: a command, documented flag, line kind or Bootstrap step removed or changed with no compatibility path. |
| **MINOR** | A new command, flag, line kind, step or backward-compatible behaviour change - and every deprecation (the old shape keeps working and says what replaces it). |
| **PATCH** | Bug fixes, doc fixes, dependency bumps. |

## Before 1.0.0

No compatibility rules apply in the 0.x series, as in WinuX before its 1.0.0: any release may
rename or remove a command, flag, line kind or Bootstrap step. Every such change carries a migration
note in `Unix/CHANGELOG.md`, under `### Breaking` or `### Removed`, so a fork reading the notes of each
release it merges knows what to change in its overlays. The [roadmap](../docs/foundation/roadmap.md) says
what each 0.x release aims at; the contract is reviewed once before 1.0.0.

## From 1.0.0 on

WinuX's ladder applies. A breaking change goes through two steps:

1. **Deprecate (MINOR).** The new shape ships and the old one keeps working; the release notes
   list it under `### Deprecated` with the migration, and `Unix/tests/contract-baseline.tsv`
   records it as a `deprecated<TAB>KIND<TAB>ITEM<TAB>VERSION` line with the version it ships in.
2. **Remove (MAJOR).** The old shape goes in the next MAJOR, under `### Removed`, with the
   migration repeated. A deprecation survives at least one MINOR release before its removal.

The only exception is a change that cannot keep the old shape working (a security fix, a macOS
change that invalidates the old behaviour): it bumps MAJOR at once, under `### Breaking`.

### How it is enforced

`Unix/tests/contract-baseline.tsv` records the contract at the last release: the commands, their
documented flags, the base config line kinds and the Bootstrap steps. `Unix/tests/contract.bats`
fails a change that removes any of them without a shipped deprecation, and a release whose bump
disagrees with its changelog sections (`### Removed` or `### Breaking` outside a MAJOR; `### Added`,
`### Changed` or `### Deprecated` in a PATCH). It skips until 1.0.0 is cut: then
`Run-Tests --update-contract-baseline` writes the first baseline, stamped with that version.

## Changelog

- Single source of truth: `Unix/CHANGELOG.md` ([Keep a Changelog](https://keepachangelog.com/en/1.1.0/)).
- Hand-curated, no emojis: every entry describes the user-visible change, not commit hashes.
- Always keep a `## [Unreleased]` section at the top; move its contents under a new
  `## [x.y.z] - YYYY-MM-DD` heading at release time.
- Sections, in order: **Added · Changed · Breaking · Deprecated · Removed · Fixed · Security**
  (omit empty ones).

## Release process

Releases are tagged `foundation/vX.Y.Z`: the prefix keeps Foundation's tags apart from those of
any other project a fork merges (WinuX tags `winux/vX.Y.Z`), so a plain `git fetch` in a fork
brings every upstream's tags without a clash, and `Merge-Upstreams` fetches exactly these.

The one tag published before the prefix, `v0.1.0`, moves once, by hand (nothing runs it for you):

```sh
git tag -a foundation/v0.1.0 -m foundation/v0.1.0 "$(git rev-list -n 1 v0.1.0)"
git push origin foundation/v0.1.0
gh release edit v0.1.0 --tag foundation/v0.1.0
git push origin --delete v0.1.0 && git tag -d v0.1.0
```

1. Move `[Unreleased]` into a dated `## [x.y.z] - YYYY-MM-DD` section of `Unix/CHANGELOG.md` and
   pick the bump from the table above.
2. Update the compare links at the bottom of `Unix/CHANGELOG.md` (`foundation/vX.Y.Z` tags).
3. From 1.0.0 on: `Run-Tests --update-contract-baseline`, then `Run-Tests`; the baseline ships in
   the same commit.
4. Commit the release edits with the change they release, in the same pull request, and merge it
   to `master`.
5. Nothing is tagged by hand. On every push to `master`, `.github/workflows/foundation-release.yml`
   reads the newest `## [x.y.z]` heading of `Unix/CHANGELOG.md`; when the tag `foundation/vx.y.z`
   does not exist yet it creates it and publishes the GitHub release with that section as its
   notes. A merge that only touched `[Unreleased]` creates nothing. The workflow runs only in
   Foundation's own repository, so the same file inside a fork never tags the fork.
