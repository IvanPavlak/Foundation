# Open-Project

Runs a project's `action` lines from `projects.conf` in order (its VS Code folders, its terminal
tabs, any other command), the macOS twin of the Windows Open-Project.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`projects.conf`](../../configuration.md#projectsconf) | `[Project]` | `[Dotfiles]`, the repository itself, and the showcase `[ExampleProject]` | A project Open-Project can open; the menu lists every section |
| [`projects.conf`](../../configuration.md#projectsconf) | `action COMMAND ARGS...` | `Open-VSCode Dotfiles`, `Open-ProjectTerminals Dotfiles` | What opening the project runs, in file order; any command, the ProjectActions of Windows; `{ProjectName}` in a line is the project's name |
| [`projects.conf`](../../configuration.md#projectsconf) | `path KEY DIR` | `ROOT $DOTFILES_ROOT`, `DOCS $DOTFILES_ROOT/docs` | Named folders of the project, read by the actions that take a key (`tab`, `docker`) |

## Decisions

1. Which projects should `Open-Project` (and a workspace's `Open-Project` action) know about?
    - Options: one `[Project]` section per project, named as you type it (`Open-Project MyProject`).
    - Default: `[Dotfiles]`, the repository itself: `path ROOT` and `path DOCS`, its two `action` lines, `tab ROOT` and `tab DOCS` (Open-ProjectTerminals) and `run DOCS npx docsify-cli serve` (Run-Project); and the showcase `[ExampleProject]`: an API and a UI folder under `$DEV`, a tab each, `run API dnr`, `run UI nir` and `docker PostgreSQL`, as in WinuX's base. Replacing a section replaces all of its lines.
    - More detail: [`projects.conf`](../../configuration.md#projectsconf)
2. What should opening a project do?
    - Options: `action` lines naming any command with its arguments, run in order; usually `Open-VSCode MyProject` and `Open-ProjectTerminals MyProject`, or `{ProjectName}` in place of the name, as on Windows. A command missing on macOS is skipped with a warning.
    - Default: a project without `action` lines opens nothing and is reported.
    - More detail: [`projects.conf`](../../configuration.md#projectsconf)
3. Which folders does the project have?
    - Options: one `path KEY DIR` line per folder (`ROOT`, `API`, `UI`, ...); `DIR` takes `~`, `$DEV` and `$DOTFILES_ROOT`.
    - Default: no paths; `Open-ProjectTerminals` then has no tab directories.
    - More detail: [Shared format](../../configuration.md#shared-format)

## Where to Put Values

`Unix/config/projects.local.conf`, created when missing. A `[MyProject]` section there adds the
project; a section with the name of a base one (`[Dotfiles]`) replaces it whole, so copy every
line you keep. `Add-Project` writes such a section for you.

## Steps Overview

1. Add the project section
2. Check the configuration

## Step 1: Add the project section

```conf
[MyProject]
path ROOT $DEV/MyProject
action Open-VSCode MyProject
action Open-ProjectTerminals MyProject
```

`Open-VSCode MyProject` needs a `MyProject` line in `vscode-folders.conf`
([Open-VSCode](../application/Open-VSCode.md)); `Open-ProjectTerminals` needs `tab` lines
([Open-ProjectTerminals](Open-ProjectTerminals.md)). For one call,
`Open-Project MyProject --vscode-workspace MyWorkspace` opens `MyWorkspace.code-workspace` (from
the `directory` of `vscode-workspaces.conf`, see [Open-VSCodeWorkspace](../application/Open-VSCodeWorkspace.md))
in place of the `Open-VSCode` folder; the other actions run as configured.

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `action` that is not a command and a `tab` or `run` key without a `path`.

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n -A4 '^\[MyProject\]' Unix/config/projects.local.conf
```

## Complete Example

`Unix/config/projects.local.conf`:

```conf
[MyProject]
path ROOT $DEV/MyProject
path API $DEV/MyProject/src/MyProject.Api
action Open-VSCode MyProject
action Open-ProjectTerminals MyProject
tab API
run API dnr
```

## Related

- [`Open-Project` in the Workflow module reference](../../modules/Workflow.md#open-project)
- [Workflow configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
