# Unix Context - Foundation

> **Purpose**: Repository context for Foundation, the macOS counterpart of WinuX (the Unix half):
> what lives where, how a command is built, which files are the source of truth. Read it before any
> work under `Unix/` or `docs/foundation/`; write code by [ShellConventions](../Instructions/ShellConventions.md).

## Safety - never act destructively on your own

Never commit, push, tag, rebase, reset, force anything, delete branches, or otherwise write git
history or a remote on your own initiative; never add or change remotes, upstream tracking or git
configuration without asking; never delete or overwrite files you were not asked to change. When
such a step seems warranted, stop, state exactly what you intend to do and wait for an explicit yes.
Creating and editing files for the task and running read-only commands are fine.

## Source of truth

The docsify pages under `docs/foundation/` are the single source of truth. This file is a map and may
lag them; when they disagree, the pages win.

| Question | Page |
| --- | --- |
| What a command does, its flags and alias | `docs/foundation/modules/<Module>.md` (one man-style entry per command, parsed by `List-Functions`) |
| What a command reads from `Unix/config` and how to set it | `docs/foundation/guides/<module>/<Command>.md` |
| The config file formats, base and overlay | `docs/foundation/configuration.md` |
| Bootstrap steps, chezmoi links, the first run | `docs/foundation/bootstrap.md` |
| Workspaces, layouts, AeroSpace | `docs/foundation/macos-workspaces.md`, `docs/foundation/adr/` |
| Forking, `.local` overlays, rooms and hallway, `Merge-Upstreams` | `docs/foundation/fork-model.md` |
| Where the project is headed | `docs/foundation/roadmap.md` |

## Layout

```
Unix/
├── modules/<Module>/   module.conf manifest, bin/ of Verb-Noun executables, optional functions.sh
│   └── Custom/<Module>/  the fork-owned Custom area, laid out the same (ships empty)
├── lib/                sourced bash: foundation.sh (the core every command sources), config,
│   │                   steps, repository, layout, workspace, project, state, terminal, testrun, ...
│   └── drivers/        aerospace.sh, wezterm.sh, browserscript.sh, inputsource.sh: the only files
│                       that call those tools
├── config/             one small file per concern (NAME.conf) and its NAME.local.conf overlay;
│   │                   upstream.conf names the paths Foundation owns
│   └── layouts/<Type>/ one <Workspace>_<Type>.conf per workspace layout
├── shell/              shellrc.sh, the shared interactive rc (zsh on macOS, bash on Linux);
│                       prediction-list.zsh, the zsh-only prediction list (PSReadLine's ListView);
│                       autocomplete-guard.zsh, the zsh-only time limit on zsh-autocomplete's worker
│                       (not sourced: zsh-autocomplete is no longer loaded)
├── home/               chezmoi source state: one link template per dotfile
├── tests/              bats suites (one per command under tests/modules/<Module>/), fixtures
├── Brewfile            the packages Foundation itself needs; Brewfile.local holds a fork's own
└── bootstrap.sh        the first run (bash 3.2): chezmoi init and apply, then Bootstrap
```

Shared asset folders stay at the repository root at WinuX's paths (`Git/`, `Btop/`, `FastFetch/`,
`WezTerm/`, `Oh-My-Posh/`, `Wallpapers/`, `LazyGit/`, `LazyDocker/`) and are linked by chezmoi. A
file that must differ per OS gets a `Unix/` sibling (`FastFetch/Unix/`, `Btop/Unix/`, `Git/Unix/`).
`Unix/config/upstream.conf` is Foundation's upstream manifest: the paths it owns (its rooms) and
the files every upstream ships byte-identical (`mirror`), read by `Merge-Upstreams`. Foundation's
project documents (`CHANGELOG.md`, `VERSIONING.md`, `CONTRIBUTING.md`, `AGENTS.md`, `CONTEXT.md`,
...) live in `Unix/`; the root files of those names are generic pointers.

## A command

Every command is an executable `Unix/modules/<Module>/bin/<Verb-Noun>` that sources
`Unix/lib/foundation.sh` through its own path, passes `foundation_require_bash`, converts
Windows-style flags with `foundation_normalize_args`, and handles `-h`/`--help` with
`foundation_common_flags`. Its header comment is its `--help` and the source of its docs entry.
The names follow WinuX for behaviour parity (`Open-Workspace`, `Kill-All`, `w`, `cw`); the shell rc
adds the Windows aliases.

Runtime names: `FOUNDATION_*` variables, `foundation_*` functions, the state folder
`$XDG_STATE_HOME/foundation/`, the data folder `$XDG_DATA_HOME/foundation/` (the AI manifest
clones); `DOTFILES_ROOT` is the clone's root.

## Configuration

No central hub: one file per concern in `Unix/config`, read through `Unix/lib/config.sh`
(`conf_lines`, `conf_value`, `conf_section`, `conf_effective`). The base `NAME.conf` ships only
generic values; a fork's own values go in `NAME.local.conf`, which Foundation's `.gitignore`
ignores and a fork may commit. Every line may start with `@TYPE` to apply on one machine type
(`machines.conf`); the base ships the `Test` type only. `Test-ConfigurationSchema` checks the files
against each other. The one exception is `upstream.conf`, the project manifest: plain `KEY VALUE`
lines read from git by `Merge-Upstreams`, no `@TYPE` and no overlay (a fork's merge settings live
in `Git/upstreams.local.conf`).

## Tests

bats-core, one suite per command (`Unix/tests/modules/<Module>/<Command>.bats`, enforced by
`tests/commands.bats`), plus shellcheck and shfmt over the files CI lints. The suites read the
generic fixture config, never `Unix/config`. Agents do not run them: hand the developer the
single `Run-Tests` command that covers the change (see ShellConventions) and wait for the result.
