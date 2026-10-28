# Shell Conventions

How code, tests, docs and configuration are written in Foundation (`Unix/`, `docs/foundation/`). Read
[UNIX_CONTEXT](../Context/UNIX_CONTEXT.md) first for the layout. These rules bind every change;
the suites named after a rule enforce it.

## Language

- No PowerShell under `Unix/`.
- Files sourced into an interactive shell (`Unix/shell/`, every `functions.sh`) are POSIX sh, so
  zsh and bash both read them.
- Standalone executables are `#!/usr/bin/env bash` and need bash 4.4+ (Homebrew bash, installed
  by Bootstrap); each calls `foundation_require_bash` before doing work.
- `Unix/bootstrap.sh` and `bootstrap-first-run` stay bash 3.2 / POSIX: they run before Homebrew
  bash exists. The libraries under `Unix/lib` are written to run under 3.2 too (no associative
  arrays, no `mapfile`, no `${x,,}`), so the pure helpers stay testable on a stock macOS.
- Style: tabs, case branches indented (`shfmt -ci`, from `Unix/.editorconfig`); `shellcheck -S
  warning` clean (`Unix/.shellcheckrc`). CI lints exactly the list `Run-Tests --lint-files` prints.
- Never use the em-dash character (U+2014): prose, comments, messages, strings. Use `-`. The sole
  exception, as in WinuX, is the browser-title class of the title patterns in
  `Unix/config/layouts/*`, which matches the hyphen or em-dash a browser puts in its window title.

## Commands

- One executable per command, `Unix/modules/<Module>/bin/<Verb-Noun>`, tracked by git as
  `100755` (`tests/commands.bats` checks the mode; a file added from Windows lands as `100644`).
- Start from an existing command of the module: resolve the own path through symlinks, source
  `lib/foundation.sh`, `foundation_require_bash`, `foundation_load` the libraries it needs,
  `foundation_normalize_args "$@"` and `foundation_common_flags "$@"`.
- The header comment is the man page: `# Name - one line.`, a blank comment line, `# Usage: ...`,
  then the behaviour. `--help` prints it, `foundation_normalize_args` reads its `--flags` to accept
  the Windows spelling (`-IncludeCurrent` for `--include-current`, `-WhatIf` for `--dry-run`), and the docs
  entry is written from it.
- A flag the command does not know is an error, never a value; nothing runs before arguments are
  checked.
- Output goes through the logging voice of `lib/log.sh` (`log_title`, `log_step`, `log_success`,
  `log_warning`, `log_error`, `log_debug`); a fatal error is `foundation_die MESSAGE`. Messages say
  what happened and what to run next.
- Parity: the same name, alias and observable result as the WinuX function; the implementation is
  free, and the Unix idiom wins when the two conflict. Keyboard shortcuts need not match across
  OSes.
- An app or process that outlives the command starts through `foundation_launch`, which drops the
  `FOUNDATION_*` variables.

## Drivers

`aerospace`, `wezterm`, the browser scripting and the input-source helper are invoked only from
their driver in `Unix/lib/drivers/` (checked by the tests). Every platform call sits in a driver so
a Linux driver can replace it later.

## Configuration

- No central hub: one small file per concern in `Unix/config`, each with a header that documents
  its line kinds. Read them through `lib/config.sh` only.
- The base `NAME.conf` ships generic values; personal values go in the overlay `NAME.local.conf`.
  Writers (`conf_add_section`, `Add-Workspace`, `Add-WindowLayout`, the FoundationConfigurator) write
  the overlay, never the base. `tests/vanilla.bats` keeps the base generic.
- Overlay rules: lines before the first section are added after the base ones (the last `KEY`
  line wins for `conf_value`); a `[Section]` replaces the base section whole; `-LINE` takes a base
  line back; `@TYPE` (or `@TYPE,TYPE`) limits a line to machine types of `machines.conf`.
- A new file or line kind: document it in the file's header, in `docs/foundation/configuration.md`
  (the Files table and its section) and in the guide of every command that reads it; teach
  `Test-ConfigurationSchema` when it refers to another file.

## Tests

- bats-core. Every command and helper has `Unix/tests/modules/<Module>/<Command>.bats`
  (`tests/commands.bats`); library suites sit in `Unix/tests/`.
- `load helpers` and call `setup_foundation` in `setup`: it points every reader at the generic
  fixture config (`tests/fixtures/config`), the state folder at the test's temp folder, and turns
  session logs and prompts off. `copy_fixture_config` or `use_empty_config` for a writable config.
- Never reach the real machine: no real app quits, window moves or tab closes, no write outside
  `$BATS_TEST_TMPDIR`. Stand in for an external tool with `stub_tool`, take one away with
  `hide_tool`; git suites use the throwaway repositories of `tests/git.bash`.
- A suite whose value is real I/O (real git, real processes, real waits) carries
  `# bats file_tags=integration`, so `Run-Tests --quick` can leave it out.
- Test behaviour, side effects, branching and edge cases, not message wording.
- Agents never run the suites. Hand the developer one command per changed area and wait for the
  result: `Run-Tests <Command>` (the suites whose path contains it), `Run-Tests commands guides
  doclinks` after a change to commands, manifests or docs, plain `Run-Tests` for a cross-cutting
  change.

## Documentation

Docs are updated in the same change as the code; a change to a documented surface without its
page is incomplete.

- A command added, renamed or removed: its entry on `docs/foundation/modules/<Module>.md` (a
  `## [Name](source URL)` heading followed at once by the `- **Description:**` and
  `- **Usage:**` bullets, plus `- **Alias:**` when it has one; alphabetical), the `command` line of
  `Unix/modules/<Module>/module.conf`, its guide `docs/foundation/guides/<module>/<Command>.md` (FULL when
  it reads a `Unix/config` file, STUB otherwise; templates in `docs/foundation/guides/README.md`) and its
  row in that folder's `README.md`, and its suite. `List-Functions --list-discrepancies` must
  report none; `tests/commands.bats` and `tests/guides.bats` enforce the set.
- A flag or behaviour change: the entry's Usage and Description, and the guide when it reads
  configuration.
- A doc page or module added or removed: `docs/foundation/_sidebar.md` and `docs/foundation/docs_overview.md`.
- A `Unix/Brewfile` change: `docs/foundation/software-list.md` (`tests/docpages.bats` compares them).
- A new failure mode or workaround: `docs/foundation/troubleshooting.md`.
- Links inside `docs/foundation` are relative and checked by `tests/doclinks.bats`; a link to a WinuX
  page is absolute (`https://ivanpavlak.github.io/WinuX/#/winux/...`).
- Docs and guides are public pages: generic values only (`MyProject`, `MyRepo`, `My-Mac`,
  `you@example.com`, `$DEV/MyRepo`), never a real host, address, account or path.
