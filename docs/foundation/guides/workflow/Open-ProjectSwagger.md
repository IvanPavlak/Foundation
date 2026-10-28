# Open-ProjectSwagger

Opens the first project's entry of the `[Swagger]` browser group unless its tab is already open:
while the backend answers, Open-Browser's check of that entry's tab decides; while it does not, a
browser window showing the failed-load page counts too.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`browser-groups.conf`](../../configuration.md#browser-groupsconf) | `[Swagger]` | none | The group that holds every project's Swagger page |
| [`browser-groups.conf`](../../configuration.md#browser-groupsconf) | `Name URL` inside `[Swagger]` | none | The project's Swagger page: `Name` is the project name (case-insensitive); the URL's host and port are what the backend probe connects to |
| [`window.conf`](../../configuration.md#files) | `problem-page-title TEXT` | `Problem loading page` | The title of a page that failed to load; while the backend is down, a browser window holding it (any case) counts as the open Swagger tab |
| [`apps.conf`](../../configuration.md#files) | `default-browser TOKEN` | `Firefox` | The browser checked and opened without `--browser TOKEN` |

## Decisions

1. Which projects have a Swagger page?
    - Options: one `MyProject URL` line per project in a `[Swagger]` group; a project without a line is skipped silently, so a workspace can run `Open-ProjectSwagger {SelectedProjects}` for every project.
    - Default: no `[Swagger]` group, nothing opens.
    - More detail: [`browser-groups.conf`](../../configuration.md#browser-groupsconf)
2. Is the entry's name unique among the browser groups?
    - Options: the entry is opened as `Open-Browser MyProject`, which looks up a group name first and a named URL after, so no group (nor a nested group's last segment) and no earlier named URL may carry the project's name.
    - Default: with a clash, Open-Browser opens that group or URL instead of the Swagger page.
    - More detail: [`browser-groups.conf`](../../configuration.md#browser-groupsconf)
3. Which title does your browser give a page that failed to load?
    - Options: a `problem-page-title TEXT` line in `window.conf` with that title's text (Firefox: Problem loading page); it only counts while the backend is down.
    - Default: Problem loading page.
    - More detail: [Files](../../configuration.md#files)

## Where to Put Values

`Unix/config/browser-groups.local.conf`, created when missing (the `problem-page-title` line goes
in `Unix/config/window.local.conf`, whose last line wins). A `[Swagger]` section there replaces
a base one of that name whole (the base ships none), so list every project's entry in it.
`Add-BrowserGroup` writes sections of this file. Give no section of the file the name of a project
with a Swagger entry: Open-Browser resolves the entry's name as a section first and as a named URL
last, so that section would open instead of the Swagger tab.

## Steps Overview

1. Add the Swagger entry
2. Check the configuration

## Step 1: Add the Swagger entry

```conf
[Swagger]
MyProject https://localhost:5001/swagger/index.html
```

Then the workspace line that opens it:

```conf
Open-ProjectSwagger {SelectedProjects}
```

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It checks that the groups workspaces open exist; the `[Swagger]` entries themselves are read back
with `grep` (Verification).

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n -A10 '^\[Swagger\]' Unix/config/browser-groups.local.conf
```

## Complete Example

`Unix/config/browser-groups.local.conf`:

```conf
[Swagger]
MyProject https://localhost:5001/swagger/index.html
MyOtherProject https://localhost:7001/swagger/index.html
```

`Unix/config/workspaces.local.conf`:

```conf
[MyWorkspace]
Open-Project
Open-ProjectSwagger {SelectedProjects}
Set-WorkspaceWindowLayout MyWorkspace
Focus-VirtualDesktop 1
```

`Unix/config/window.local.conf` (only for a browser whose failed-load title is not Firefox's):

```conf
problem-page-title  Problem loading page
```

## Related

- [`Open-ProjectSwagger` in the Workflow module reference](../../modules/Workflow.md#open-projectswagger)
- [`Open-Browser` in the Application module reference](../../modules/Application.md#open-browser)
- [Close-Project](Close-Project.md)
- [Workflow configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
