# Add-Project

Adds a project as a new `[NAME]` section of `projects.local.conf`, with its path keys, terminal
tabs, Run-Project commands and Open-Project actions.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`projects.conf`](../../configuration.md#projectsconf) | `[Project]` | `[Dotfiles]`, the repository itself, and the showcase `[ExampleProject]` | The project; Add-Project writes the section and refuses a name already in the base file or the overlay |
| [`projects.conf`](../../configuration.md#projectsconf) | `path KEY DIR` | `path ROOT $DOTFILES_ROOT` | A named folder, written for each `--path KEY DIR`; without any, `path ROOT` is the current directory. A folder under the dev root is written as `$DEV/...`, one under the home folder as `~/...` |
| [`projects.conf`](../../configuration.md#projectsconf) | `action COMMAND ARGS...` | `Open-VSCode Dotfiles`, `Open-ProjectTerminals Dotfiles` | What Open-Project runs, written for each `--action "LINE"`; without any, `action Open-VSCode NAME` and `action Open-ProjectTerminals NAME` |
| [`projects.conf`](../../configuration.md#projectsconf) | `tab KEY [DIR]` | `tab ROOT` | A WezTerm tab titled `NAME.KEY` in path KEY (or DIR), written for each `--tab KEY [DIR]`; without a `--path`, one `tab ROOT` |
| [`projects.conf`](../../configuration.md#projectsconf) | `run KEY COMMAND` | `run ROOT npx docsify-cli serve docs` | What Run-Project types into tab KEY, written for each `--run KEY COMMAND` |

The lines are written in the order the base sections use: paths, actions, tabs, run commands.
`docker TARGET` lines are not written by Add-Project; add them to the section by hand.

## Decisions

1. What is the project called?
    - Options: any name without `[` or `]`, typed as `Open-Project MyProject` and used in tab titles (`MyProject.API`).
    - Default: none; the first plain argument (or `--name NAME`). Give it first: a plain word right after `--tab KEY` is taken as that tab's DIR.
    - More detail: [`projects.conf`](../../configuration.md#projectsconf)
2. Which folders does it have?
    - Options: one `--path KEY DIR` per folder (`ROOT`, `API`, `UI`, ...); an absolute DIR under the dev root or the home folder is written as `$DEV/...` or `~/...`, so the line stays machine-independent.
    - Default: `path ROOT` is the current directory, with one `tab ROOT`.
    - More detail: [Shared format](../../configuration.md#shared-format)
3. What should Open-Project run?
    - Options: one `--action "LINE"` per command with its arguments, quoted when it has spaces (`--action "Open-Browser MyGroup"`); like `--run`, it takes one argument.
    - Default: `Open-VSCode NAME` and `Open-ProjectTerminals NAME`. `Open-VSCode NAME` needs a `NAME` line in `vscode-folders.conf`.
    - More detail: [Open-Project](../workflow/Open-Project.md)
4. Which terminal tabs and run commands should it have?
    - Options: `--tab KEY` for a tab in path KEY, `--tab KEY DIR` for one in its own folder (`DEFAULT` is the home folder); `--run KEY "COMMAND"` for what Run-Project types into tab KEY, quoted when it has spaces: `--run` takes one argument, so an unquoted `--run API dotnet run` writes `run API dotnet` and takes the last word as the project name. A run key needs a tab of the same key: Run-Project types commands only into tabs.
    - Default: one `tab ROOT` when no `--path` is given, otherwise no tabs; no run commands.
    - More detail: [`projects.conf`](../../configuration.md#projectsconf)

## Where to Put Values

`Unix/config/projects.local.conf`, created with a header when missing and backed up into
`Backups/Unix/Config/` before every later write (nothing is written when the backup fails).
Add-Project only appends new sections. To change an existing project, edit its section in the
overlay; to change the base `[Dotfiles]`, write a `[Dotfiles]` section in the overlay, which
replaces the base one whole. `@TYPE` limits a line to machine types (`@Work tab API`).

## Steps Overview

1. Add the project
2. Check the configuration

## Step 1: Add the project

```bash
Add-Project MyProject --path ROOT ~/Development/GitHub/MyProject --path API ~/Development/GitHub/MyProject/src/MyProject.Api --tab API --run API "dotnet run"
```

writes (the dev root here being `~/Development/GitHub`):

```conf
[MyProject]
path ROOT $DEV/MyProject
path API $DEV/MyProject/src/MyProject.Api
action Open-VSCode MyProject
action Open-ProjectTerminals MyProject
tab API
run API dotnet run
```

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `action` that is not a command, a `tab` without a path key or folder of its own,
and a `run` key without a `tab` line of the same key.

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n -A8 '^\[MyProject\]' Unix/config/projects.local.conf
```

## Complete Example

`Unix/config/projects.local.conf`:

```conf
[MyProject]
path ROOT $DEV/MyProject
path API $DEV/MyProject/src/MyProject.Api
path UI $DEV/MyProject-ui
action Open-VSCode MyProject
action Open-ProjectTerminals MyProject
tab API
tab UI
@Work tab LOGS ~/Library/Logs
run API dotnet run
run UI npm run dev
```

## Related

- [`Add-Project` in the Configuration module reference](../../modules/Configuration.md#add-project)
- [Configuration configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
