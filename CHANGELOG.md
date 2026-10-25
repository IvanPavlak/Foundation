# Changelog

All notable changes to **Foundation** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). See [VERSIONING.md](VERSIONING.md) for how we version and release; before 1.0.0 any release may rename or remove part of the contract, with a migration note here.

<!-- Sections, in order (omit any that are empty in a tagged release): Added · Changed · Breaking · Deprecated · Removed · Fixed · Security -->

## [Unreleased]

## [0.1.0] - 2026-10-25

### Added

- **Foundation, the macOS counterpart of WinuX, as its own repository.** The first public release of the Unix half that grew inside a fork of WinuX: bash executables in `Unix/modules/<Module>/bin` with the WinuX command names and aliases (`Open-Workspace` and `w`, `Close-Workspace` and `cw`, `Kill-All`, `Open-Browser` and `b`, `Update-Repositories`, the git shorthands), sourced libraries in `Unix/lib` with every AeroSpace, WezTerm and browser call in a driver, small per-concern config files in `Unix/config` with `.local.conf` overlays and `@TYPE` machine-type lines, chezmoi link templates in `Unix/home`, the `Unix/bootstrap.sh` first run handing over to `Bootstrap` and its switchable steps, the AI artifacts, marketplace and MCP server deployment, and the Custom area for a fork's own commands. The base config ships the `Test` machine type and generic values only.
- **`Merge-Upstream` (Git module) and `Unix/config/upstream.conf`.** Merges an upstream remote and stops before the commit; with `--owned-only` it takes only the paths Foundation owns, so a fork of both WinuX and Foundation takes each half from its own upstream. See the Fork Model page.
- **Tests and CI.** One bats suite per command, the library suites, the docs and guide gates, shellcheck and shfmt, run by `Run-Tests` and by the `Unix Tests` check on macOS.
- **Documentation.** The docsify site under `docs/unix/`: the getting-started overview, a man-style page per module, a configuration guide per command, configuration, bootstrap, workspaces, AI, software, backups, troubleshooting, the fork model and the roadmap.

[Unreleased]: https://github.com/IvanPavlak/Foundation/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/IvanPavlak/Foundation/releases/tag/v0.1.0
