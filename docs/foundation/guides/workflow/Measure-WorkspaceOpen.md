# Measure-WorkspaceOpen

Opens one workspace many times under alternating layout settings and compares the variants, the
controlled experiment behind the Open-Workspace speed work.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `[Workspace]` and its action lines | `[Example]` is measured when no workspace is named | The workspace opened on every run; one that closes the calling tab, or needs a project none was given for, is refused |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `layout-early-move on\|off` | `off` | The Baseline value of that setting (`off` without a line); the other variant flips it |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `layout-stable-ms N` | `500` | The Baseline value of that setting (`500` without a line); the other variant uses the other known value (1000 or 500) |
| [`workspace-templates.conf`](../../configuration.md#workspace-templatesconf) | `[Template]` with `var` and action lines | a commented example, no template | A templated workspace is judged on its expanded actions; one whose template does not resolve is refused |

## Decisions

1. Which workspace should the experiment open?
    - Options: any `workspaces.conf` section whose actions keep the calling terminal tab (no `Terminate-WindowsTerminalTabs --only-current` or `--include-current`); pass `PROJECT` arguments when it has an `Open-Project` without a project.
    - Default: `Example`, which ships in the base file.
    - More detail: [`workspaces.conf`](../../configuration.md#workspacesconf)
2. What are the current layout settings the variants are compared against?
    - Options: `layout-early-move on|off` and `layout-stable-ms N` before the first section; the run never edits a file, each variant's values reach the open through `FOUNDATION_SETTING_OVERRIDES`.
    - Default: the base ships `layout-early-move off` and `layout-stable-ms 500`, and a missing line counts as that base value. `benchmark off` needs no change: every run of the experiment records its benchmark row anyway (as on Windows).
    - More detail: [State](../../configuration.md#state)
3. Does a templated workspace resolve?
    - Options: a `workspace-templates.conf` section with every `var` given a value (a default, a `set` line or `--VARIABLE VALUE` after `--`).
    - Default: a workspace without a `template` line needs no template.
    - More detail: [`workspace-templates.conf`](../../configuration.md#workspace-templatesconf)

## Where to Put Values

`Unix/config/workspaces.local.conf` and `Unix/config/workspace-templates.local.conf`, created when
missing. Lines before the first section (`layout-early-move`, `layout-stable-ms`) are
added to the base ones and the overlay's line wins; a `[Section]` there replaces the base one of the
same name whole; `@TYPE` limits a line to machine types.

## Steps Overview

1. Pick the settings the Baseline runs with
2. Check the configuration

## Step 1: Pick the settings the Baseline runs with

```conf
layout-early-move off
layout-stable-ms 500
```

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports a template that does not resolve and an action that is not a command.

## Verification

```bash
Test-ConfigurationSchema --quiet
Measure-WorkspaceOpen MyWorkspace MyProject --dry-run
Measure-WorkspaceOpen --list-sessions
Measure-WorkspaceOpen --report
Measure-WorkspaceOpen --report 20260101-100000 --reference "layout-early-move=on"
```

`--dry-run` prints the variants and the run plan and opens nothing; `--list-sessions` lists the
recorded sessions with their ids; `--report` replays the summary of the last session, or of the
one named, compared with the first variant or the one `--reference` names. Read Clean, Retries and
NotApplied before the seconds: a variant that wins the median with layout retries is not faster.

## Complete Example

`Unix/config/workspaces.local.conf`:

```conf
layout-early-move off
layout-stable-ms 500

[MyWorkspace]
template Project
```

`Unix/config/workspace-templates.local.conf`:

```conf
[Project]
var Repository {Workspace}Repository
Open-Project {Workspace}
Open-Browser {Repository} AI
Set-WorkspaceWindowLayout {Workspace}
Focus-VirtualDesktop 1
```

## Related

- [`Measure-WorkspaceOpen` in the Workflow module reference](../../modules/Workflow.md#measure-workspaceopen)
- [Open-Workspace](Open-Workspace.md)
- [Get-WorkspaceBenchmark](Get-WorkspaceBenchmark.md)
- [Workflow configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
