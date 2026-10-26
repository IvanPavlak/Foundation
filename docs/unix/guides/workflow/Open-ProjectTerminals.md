# Open-ProjectTerminals

Opens a project's WezTerm tabs titled `<Project>.<KEY>` in the window this shell runs in, each
greeting with fastfetch and, inside a repository, onefetch. Afterwards the window's first tab is
selected, as on Windows; `--focus-tab` picks another (an index, a tab title, or `origin`, the tab
the command was typed in).

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`projects.conf`](../../configuration.md#projectsconf) | `[Project]` | `[Dotfiles]`, the repository itself, and the showcase `[ExampleProject]` | A project; the menu lists only the projects with `tab` lines, in file order (base first). Windows orders this menu by its own ProjectTerminals list; the Mac has the one project order |
| [`projects.conf`](../../configuration.md#projectsconf) | `tab KEY [DIR]` | `tab ROOT`, `tab DOCS` (Dotfiles) | One tab titled `<Project>.<KEY>`, opened in path `KEY`, in `DIR` when given, or in the home folder for `DEFAULT`; `tab NAME ~` is the Windows name-only tab, a plain home-folder tab titled `<Project>.NAME` |
| [`projects.conf`](../../configuration.md#projectsconf) | `path KEY DIR` | `ROOT $DOTFILES_ROOT`, `DOCS $DOTFILES_ROOT/docs` (Dotfiles) | The folder a `tab KEY` without `DIR` opens in; a tab whose folder is missing is skipped with a warning |
| [`greeting.conf`](../../configuration.md#files) | `onefetch-in-project-terminals on\|off` | `on` | Whether the first greeting of each new tab draws the onefetch panel; `--invoke-onefetch` and `--no-onefetch` decide it for one call |

## Decisions

1. Which tabs should a project open?
    - Options: one `tab KEY` line per tab, in the order they should open; `KEY` names a `path` line, or give `tab KEY DIR` to set the folder directly, or `tab DEFAULT` for the home folder. A plain tab with a title of its own (the Windows `@{ Key = "Name" }`) is `tab Name ~`.
    - Default: a project without `tab` lines opens no tab and is left out of the menu.
    - More detail: [`projects.conf`](../../configuration.md#projectsconf)
2. Which folders do the tabs open in?
    - Options: `path KEY DIR` lines; `DIR` takes `~`, `$DEV` and `$DOTFILES_ROOT`.
    - Default: none; a `tab` key with neither a `DIR` nor a path is skipped with a warning (and reported by Test-ConfigurationSchema), so a mistyped key is caught rather than opened in the home folder.
    - More detail: [Shared format](../../configuration.md#shared-format)
3. Should a new project tab show the onefetch panel straight away?
    - Options: `onefetch-in-project-terminals on` or `off`; `c` in the tab always draws it later.
    - Default: on.
    - More detail: [`Show-TerminalGreeting`](../../modules/System.md#show-terminalgreeting)

## Where to Put Values

`Unix/config/projects.local.conf` for the project section (a section with the name of a base one,
`[Dotfiles]`, replaces it whole, so copy every line you keep) and `Unix/config/greeting.local.conf`
for the greeting line (it has no sections: the overlay's line wins over the base one, and `@TYPE`
sets it per machine type). Both are created when missing.

## Steps Overview

1. Add the project's tabs
2. Choose the first greeting
3. Check the configuration

## Step 1: Add the project's tabs

```conf
[MyProject]
path ROOT $DEV/MyProject
path API $DEV/MyProject/src/MyProject.Api
action Open-VSCode MyProject
action Open-ProjectTerminals MyProject
tab ROOT
tab API
```

`run KEY COMMAND` lines next to them are what Run-Project types into those tabs.

## Step 2: Choose the first greeting

```conf
onefetch-in-project-terminals off
```

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports a `tab` or `run` key without a `path`.

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n -A8 '^\[MyProject\]' Unix/config/projects.local.conf
grep -n 'onefetch-in-project-terminals' Unix/config/greeting.conf Unix/config/greeting.local.conf
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
tab ROOT
tab API
tab UI
tab DEFAULT
run API dnr
run UI nir
```

`Unix/config/greeting.local.conf`:

```conf
onefetch-in-project-terminals off
```

## Related

- [`Open-ProjectTerminals` in the Workflow module reference](../../modules/Workflow.md#open-projectterminals)
- [Open-Project](Open-Project.md)
- [Close-Project](Close-Project.md)
- [Workflow configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
