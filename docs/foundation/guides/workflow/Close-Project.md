# Close-Project

Closes what Open-Project opened for a project (its VS Code windows, browser tabs and terminal
tabs) and leaves the workspace's other apps running.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`projects.conf`](../../configuration.md#projectsconf) | `[Project]` | `[Dotfiles]`, the repository itself, and the showcase `[ExampleProject]` | A project Close-Project can close; the menu lists every section |
| [`projects.conf`](../../configuration.md#projectsconf) | `action Open-VSCode FOLDER` | `action Open-VSCode Dotfiles` | The VS Code folders whose windows close; other `action` lines are not undone |
| [`vscode-folders.conf`](../../configuration.md#files) | `NAME DIR` | `Dotfiles $DOTFILES_ROOT` | The folder an `Open-VSCode` action names; the last segment of `DIR` must be a whole segment of the window title for the window to close |
| [`browser-groups.conf`](../../configuration.md#browser-groupsconf) | `[Swagger]` group, `Name URL` line named after the project | none | With an entry, tabs showing "Swagger UI" close too, and when its URL's host is `localhost` or `127.0.0.1` the failed-load tabs as well |
| [`window.conf`](../../configuration.md#files) | `problem-page-title TEXT` | `Problem loading page` | The failed-load title those tabs show (any case) |

## Decisions

1. Which projects should `Close-Project` know about?
    - Options: one `[Project]` section per project in `projects.conf`, the same sections Open-Project reads.
    - Default: `[Dotfiles]` and `[ExampleProject]`; an unknown name is reported and the next project is closed.
    - More detail: [`projects.conf`](../../configuration.md#projectsconf)
2. Which VS Code windows belong to the project?
    - Options: one `action Open-VSCode FOLDER` line per folder, each `FOLDER` a `NAME DIR` line of `vscode-folders.conf`. The window closes when the last segment of `DIR` (`MyProject`) is a whole segment of its title, so a `myproject-ui` window survives.
    - Default: no `Open-VSCode` action, no VS Code window closes.
    - More detail: [Files](../../configuration.md#files)
3. Which browser tabs belong to the project?
    - Options: every tab whose title or URL contains the project name (case-insensitive), always; add a `MyProject URL` line to the `[Swagger]` group to also close the Swagger UI tabs and, for a URL on this machine (`localhost`, `127.0.0.1`), the failed-load tabs (`problem-page-title` of `window.conf`); a remote Swagger URL leaves unrelated failed-load tabs open, as on Windows. Pick project names that do not occur in unrelated page titles.
    - Default: no Swagger entry, only tabs that name the project close.
    - More detail: [`browser-groups.conf`](../../configuration.md#browser-groupsconf)

## Where to Put Values

`Unix/config/projects.local.conf` for the project section (a section with the name of a base one
replaces it whole), `Unix/config/vscode-folders.local.conf` for the folder lines (lines are added
to the base ones; `-LINE` takes a base line back) and `Unix/config/browser-groups.local.conf` for
the `[Swagger]` group (a section there replaces the base one of the same name whole). Each file is
created when missing.

## Steps Overview

1. Name the project's VS Code folders
2. Add the Swagger entry
3. Check the configuration

## Step 1: Name the project's VS Code folders

The project's `Open-VSCode` actions decide which windows close; each folder needs its line in
`vscode-folders.local.conf`.

```conf
[MyProject]
path ROOT $DEV/MyProject
action Open-VSCode MyProject
action Open-ProjectTerminals MyProject
```

```conf
MyProject    $DEV/MyProject
```

The terminal tabs titled `MyProject.*` close through Close-ProjectTerminals and need nothing more.

## Step 2: Add the Swagger entry

Only for a project with an API: the entry named after the project makes the Swagger tabs part of
it.

```conf
[Swagger]
MyProject https://localhost:5001/swagger/index.html
```

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `action` that is not a command and a `tab` or `run` key without a `path`.

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n -A4 '^\[MyProject\]' Unix/config/projects.local.conf
grep -n '^MyProject' Unix/config/vscode-folders.local.conf
```

## Complete Example

`Unix/config/projects.local.conf`:

```conf
[MyProject]
path ROOT $DEV/MyProject
action Open-VSCode MyProject
action Open-ProjectTerminals MyProject
tab ROOT
```

`Unix/config/vscode-folders.local.conf`:

```conf
MyProject    $DEV/MyProject
```

`Unix/config/browser-groups.local.conf`:

```conf
[Swagger]
MyProject https://localhost:5001/swagger/index.html
```

## Related

- [`Close-Project` in the Workflow module reference](../../modules/Workflow.md#close-project)
- [Open-Project](Open-Project.md)
- [Workflow configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
