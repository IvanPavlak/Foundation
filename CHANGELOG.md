# Changelog

All notable changes to **Foundation** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). See [VERSIONING.md](VERSIONING.md) for how we version and release; before 1.0.0 any release may rename or remove part of the contract, with a migration note here.

<!-- Sections, in order (omit any that are empty in a tagged release): Added · Changed · Breaking · Deprecated · Removed · Fixed · Security -->

## [Unreleased]

### Fixed

- **A workspace window still resizing is no longer placed as if it had settled when the wait runs slowly.** `layout_wait` (Set-WorkspaceWindowLayout's wait) counts a window as ready once its title and its frame have held for `stable-ms`. Its first frame read was recorded without restarting the clock and could make the window ready at once, so when a pass took longer than `stable-ms` (a busy Mac, the 3-CPU CI runner) a window restoring its bounds, VS Code above all, was declared ready on a frame seen only once. A frame now needs a second matching read, at most one more poll. Covered by a new `layout.bats` test with a slow window-list read, which fails on the old code.
- **CI is faster and runs once per pull request.** The doc-link check computes each page's anchors once instead of once per link (145 s to a few seconds on the runner), and the `Unix` workflow runs on pull requests and on pushes to `master` only, not again for every push to a pull request's branch.
- **The Fork Model's two-upstream setup no longer breaks on tags.** Branches stay under each remote's name, but a clone keeps every tag in one namespace and both WinuX and Foundation tag `v0.1.0` and up, so a fork of both had every Foundation fetch refuse to overwrite WinuX's tags of the same name (and `Merge-Upstream`, which fetches first, stopped there). The one-time setup now keeps each upstream's tags under a prefix, `winux/v1.7.0` and `foundation/v0.1.0` (`--no-tags` plus a `+refs/tags/*:refs/tags/<prefix>/*` refspec per remote), and ends with a check: no bare tag left, both prefixes listed, `Merge-Upstream macupstream --dry-run` up to date. The `Merge-Upstream` guide points at it. Documentation only.

## [0.1.0] - 2026-10-25

### Added

- **Foundation, the macOS counterpart of WinuX, as its own repository.** The first public release of the Unix half that grew inside a fork of WinuX: bash executables in `Unix/modules/<Module>/bin` with the WinuX command names and aliases (`Open-Workspace` and `w`, `Close-Workspace` and `cw`, `Kill-All`, `Open-Browser` and `b`, `Update-Repositories`, the git shorthands), sourced libraries in `Unix/lib` with every AeroSpace, WezTerm and browser call in a driver, small per-concern config files in `Unix/config` with `.local.conf` overlays and `@TYPE` machine-type lines, chezmoi link templates in `Unix/home`, the `Unix/bootstrap.sh` first run handing over to `Bootstrap` and its switchable steps, the AI artifacts, marketplace and MCP server deployment, and the Custom area for a fork's own commands. The base config ships the `Test` machine type and generic values only.
- **`Merge-Upstream` (Git module) and `Unix/config/upstream.conf`.** Merges an upstream remote and stops before the commit; with `--owned-only` it takes only the paths Foundation owns, so a fork of both WinuX and Foundation takes each half from its own upstream. See the Fork Model page.
- **Tests and CI.** One bats suite per command, the library suites, the docs and guide gates, shellcheck and shfmt, run by `Run-Tests` and by the `Unix Tests` check on macOS.
- **Documentation.** The docsify site under `docs/unix/`: the getting-started overview, a man-style page per module, a configuration guide per command, configuration, bootstrap, workspaces, AI, software, backups, troubleshooting, the fork model and the roadmap.

[Unreleased]: https://github.com/IvanPavlak/Foundation/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/IvanPavlak/Foundation/releases/tag/v0.1.0
