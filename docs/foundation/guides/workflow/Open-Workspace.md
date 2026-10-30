# Open-Workspace

Runs a workspace's actions from `workspaces.conf` (apps, projects, browser groups, the window
layout), records what it opened for Close-Workspace and appends a benchmark row (alias `w`).

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `[Workspace]` and its action lines | Example, Test, Fullscreen, Empty, Default, SecureBrowser | A workspace: one action per line, run top to bottom (a Foundation command, `Open-<App>` for an `apps.conf` app, or `Return`); `@TYPE`, `%SET` and `+A,B` / `+!A,B` prefixes limit a line; a trailing `&` runs an app-starting action in the background |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `default-workspace NAME` | `Default` | What an empty Enter at the workspace menu opens |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `template NAME`, `set`, `replace`, `drop`, `add` | none | A workspace that stamps out a template under its own name, with its changes |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `benchmark on\|off` | `off` | Whether each open appends a row for Get-WorkspaceBenchmark (off without a line, as WinuX's `WorkspaceBenchmark.Enabled`) |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `benchmark-display table\|line\|none` | `table` | What the end of a benchmarked open shows: the workspace's recent runs (Get-WorkspaceBenchmark), one Timing line, or nothing |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `layout-early-move on\|off`, `layout-stable-ms N`, `layout-absent-grace-seconds N`, `simple-layouts NAME...` | `off`, `500`, `10`, `Fullscreen Empty` | How the workspace's Set-WorkspaceWindowLayout action places windows |
| [`workspace-templates.conf`](../../configuration.md#workspace-templatesconf) | `[Template]` with `var NAME [DEFAULT...]` and `[:ID] ACTION...` lines | a commented example, no template | The action list a `template` line stamps out |
| [`projects.conf`](../../configuration.md#projectsconf) | `[Project]` | `[Dotfiles]` and `[ExampleProject]` | The projects the up-front project menu offers for an `Open-Project` without a project, and the names `+A,B` scopes and `{SelectedProjects}` take |
| [`vscode-workspaces.conf`](../../configuration.md#files) | `default WORKSPACE NAME` | none | Opens `NAME.code-workspace` in place of the folder the workspace's Open-VSCode action would open |
| [`vscode-workspaces.conf`](../../configuration.md#files) | `directory PATH` | `$DOTFILES_ROOT/VSCode/Workspaces` | Where the `.code-workspace` files are |
| [`kill-all.conf`](../../configuration.md#files) | `keep TOKEN` | `Terminal`, `Finder`, `AeroSpace` | Apps whose pre-existing windows the layout adopted are not recorded, so `cw` never closes them |
| [`machines.conf`](../../configuration.md#files) | `type`, `host HOSTNAME TYPE`, `default TYPE`, `small-display TYPE`, `small-display-width POINTS`, `layout-override TYPE OTHER`, `dev-root PATH` | `type Test`, `default Test`, `small-display-width 3000` | The machine type, so the `@TYPE` lines that apply, the layout set (`layouts/<Type>/`) the benchmark row, the layout and the `%SET` lines use, and `$DEV` in every path |
| [`zones.conf`](../../configuration.md#zonesconf) | `ZONESET COLUMN...`, `alias ZONESET NAME ZONE`, `parking-workspace NAME` | the zone sets Zero to Nine, `parking-workspace P` | The zone sets the layout files name and where stray windows are parked |

## Decisions

1. Which workspaces exist and what does each open?
    - Options: one `[Workspace]` section per workspace with its action lines, usually `Open-<App>` lines, `Open-Project`, `Open-Browser GROUP...`, `Set-WorkspaceWindowLayout {Workspace}` and `Focus-VirtualDesktop 1`. An action macOS does not have is reported and skipped.
    - Default: the base workspaces (Example, Test, Fullscreen, Empty, Default, SecureBrowser).
    - More detail: [`workspaces.conf`](../../configuration.md#workspacesconf)
2. What should a bare `w` open on Enter?
    - Options: `default-workspace NAME`, a workspace section; a name without a section makes Enter cancel.
    - Default: `Default`.
    - More detail: [`workspaces.conf`](../../configuration.md#workspacesconf)
3. Should several workspaces share one template?
    - Options: a `[Template]` section in `workspace-templates.conf`, and in each workspace a `template NAME` line plus `set`, `replace`, `drop` and `add` lines; a workspace with a `template` line takes no other lines. A template error opens nothing of that workspace.
    - Default: no templates; every workspace lists its own actions.
    - More detail: [`workspace-templates.conf`](../../configuration.md#workspace-templatesconf)
4. Which projects does a workspace open?
    - Options: `Open-Project MyProject` fixes them (typed projects do not replace a fixed one, and the line keeps its flags such as `--run-app`); a bare `Open-Project` shows the project menu up front (Enter skips it) unless the projects are typed (`w MyWorkspace MyProject`). `+MyProject LINE` and `+!MyProject LINE` run a line only for (or never for) those projects. A closing `Terminate-WindowsTerminalTabs --only-current` keeps the tab when the workspace is rerun from one of its own project tabs (`MyProject.ROOT`).
    - Default: the projects the `Open-Project` lines name.
    - More detail: [`projects.conf`](../../configuration.md#projectsconf)
5. Should a workspace open a VS Code multi-root workspace instead of its project folder?
    - Options: `default MyWorkspace MyProject` in `vscode-workspaces.conf`, with `MyProject.code-workspace` in its `directory`; `--vscode-workspace NAME` does it for one open.
    - Default: no `default` line, Open-VSCode opens the folder.
    - More detail: [`Open-VSCodeWorkspace`](../../modules/Application.md#open-vscodeworkspace)
6. Which apps must `cw` never close even when the layout moved their windows?
    - Options: `keep TOKEN` lines of `kill-all.conf`, tokens of `apps.conf` or app names as AeroSpace reports them. Windows the open created are recorded regardless.
    - Default: Terminal, Finder and AeroSpace.
    - More detail: [`Kill-All`](../../modules/System.md#kill-all)
7. Which layout set does this Mac use?
    - Options: a `host HOSTNAME TYPE` line for the Mac, or `default TYPE`; `small-display TYPE` for the built-in panel and `layout-override TYPE OTHER` to borrow another type's layouts. Every workspace's layout must exist in each set the Mac can use. A workspace line `%SET LINE` runs only on layout set SET, so an action can follow the layout applied rather than the machine type (`%Work Open-Browser --no-menu --instances 2`).
    - Default: the `Test` set.
    - More detail: [Files](../../configuration.md#files)
8. How should the layout step behave?
    - Options: `layout-early-move on|off`, `layout-stable-ms N` (milliseconds a window title must hold), `layout-absent-grace-seconds N` (seconds before the layout stops waiting for an app that is not running), `simple-layouts NAME...` for layouts that only fill each desktop, `zones.conf` zone sets and `parking-workspace`. Measure-WorkspaceOpen compares the first two.
    - Default: early move off, 500 ms, `Fullscreen Empty`, the shipped zone sets and parking workspace `P`.
    - More detail: [`zones.conf`](../../configuration.md#zonesconf)
9. Should each open be benchmarked, and what should it show?
    - Options: `benchmark on` or `benchmark off`; `benchmark-display table`, `line` or `none`.
    - Default: off, as WinuX's base; `table` when on. Each row records the open's mode (Plain or Alongside) and the layout's attempts; `line` adds `retries N` when a desktop had to be arranged again.
    - More detail: [State](../../configuration.md#state)

## Where to Put Values

The `.local.conf` overlay of each file, created when missing: `workspaces.local.conf`,
`workspace-templates.local.conf`, `vscode-workspaces.local.conf`, `kill-all.local.conf`,
`machines.local.conf` and `zones.local.conf`. Lines before the first section are added to the base
ones (for a single-value line such as `default-workspace` the overlay's line wins); a `[Section]`
replaces the base one of the same name whole; `-LINE` takes a base line back (`-keep Finder`);
`@TYPE` limits a line to machine types. `Add-Workspace` writes a workspace section, and
Initialize-Configuration writes `host` and `dev-root` on a fresh clone.

## Steps Overview

1. Add the workspace
2. Share actions through a template
3. Choose the VS Code workspace
4. Map this Mac to its layout set
5. Check the configuration

## Step 1: Add the workspace

```conf
default-workspace MyWorkspace

[MyWorkspace]
Open-ClaudeDesktop
Open-Project MyProject
Open-Browser MyRepository AI
+MyProject Open-ProjectSwagger {SelectedProjects}
Set-WorkspaceWindowLayout MyWorkspace
Focus-VirtualDesktop 1
```

`Set-WorkspaceWindowLayout MyWorkspace` needs `layouts/<Type>/MyWorkspace_<Type>.conf` in every
layout set this Mac uses (Add-WindowLayout creates one).

## Step 2: Share actions through a template

`workspace-templates.local.conf`:

```conf
[Project]
var Repository {Workspace}Repository
Open-ClaudeDesktop
:project Open-Project {Workspace}
Open-Browser {Repository} AI
Set-WorkspaceWindowLayout {Workspace}
Focus-VirtualDesktop 1
```

`workspaces.local.conf`:

```conf
[MyProject]
template Project
add after project Open-ProjectSwagger {SelectedProjects}
```

## Step 3: Choose the VS Code workspace

```conf
default MyWorkspace MyProject
```

## Step 4: Map this Mac to its layout set

```conf
type Work
host My-Mac Work
@Work dev-root ~/Development
```

## Step 5: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports a template that does not resolve, an action that is not a command, an `Open-Project` or
`+A,B` scope naming an unknown project, a `%SET` scope naming no machine type or layout set, an `Open-Browser` group that does not exist, a trailing `&` on a command that cannot run in the background, a layout
missing from a set the Mac uses, an unknown `default-workspace` and a `vscode-workspaces.conf`
`default` without its file.

## Verification

```bash
Test-ConfigurationSchema --quiet
Visualize-Layouts MyWorkspace
Get-WorkspaceState MyWorkspace
```

`Get-WorkspaceState` shows what the last open recorded, so what `cw` would close.

## Complete Example

`Unix/config/workspaces.local.conf`:

```conf
default-workspace MyWorkspace
benchmark on
benchmark-display line
layout-early-move off
layout-stable-ms 500
layout-absent-grace-seconds 10

[MyWorkspace]
Open-ClaudeDesktop
Open-Project MyProject
Open-Browser MyRepository AI
+MyProject Open-ProjectSwagger {SelectedProjects}
@Laptop Open-Slack
%Work Open-Browser --no-menu --instances 2
Set-WorkspaceWindowLayout MyWorkspace
Focus-VirtualDesktop 1

[MyProject]
template Project
set Repository MyRepository
add after project Open-ProjectSwagger {SelectedProjects}
```

`Unix/config/workspace-templates.local.conf`:

```conf
[Project]
var Repository {Workspace}Repository
Open-ClaudeDesktop
:project Open-Project {Workspace}
Open-Browser {Repository} AI
Set-WorkspaceWindowLayout {Workspace}
Focus-VirtualDesktop 1
```

`Unix/config/vscode-workspaces.local.conf`:

```conf
default MyWorkspace MyProject
```

`Unix/config/kill-all.local.conf`:

```conf
keep Slack
```

`Unix/config/machines.local.conf`:

```conf
type Work
type Laptop
host My-Mac Work
default Work
small-display Laptop
@Work dev-root ~/Development
```

`Unix/config/zones.local.conf`:

```conf
parking-workspace P
```

## Related

- [`Open-Workspace` in the Workflow module reference](../../modules/Workflow.md#open-workspace)
- [`Set-WorkspaceWindowLayout` in the Window module reference](../../modules/Window.md#set-workspacewindowlayout)
- [macOS Workspaces](../../macos-workspaces.md)
- [Close-Workspace](Close-Workspace.md)
- [Workflow configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
