# Get-WorkspaceBenchmark

Shows the benchmark rows Open-Workspace records, one per workspace open, with a median line per
workspace, mode (Plain or Alongside) and early-move mode, its retries and runs not applied.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `benchmark-history N` | `10` | How many of the most recent rows are shown when no `--last N` is given |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `benchmark on\|off` | `off` | Read by Open-Workspace: only `on` records, so without it no new rows appear here (as WinuX's `WorkspaceBenchmark.Enabled`) |

## Decisions

1. How many recent opens should the table show by default?
    - Options: `benchmark-history N`, a whole number; `--last N` overrides it for one call, and `--last 0` shows every row.
    - Default: 10 (also when the line is missing).
    - More detail: [State](../../configuration.md#state)
2. Should workspace opens be recorded at all?
    - Options: `benchmark on` or `benchmark off`.
    - Default: off, as WinuX's base: Open-Workspace appends no row and shows nothing; with `on` it shows what `benchmark-display` says (`table`, the default, `line` or `none`).
    - More detail: [`workspaces.conf`](../../configuration.md#workspacesconf)

## Where to Put Values

`Unix/config/workspaces.local.conf`, created when missing. Both lines go before its first section;
the overlay's line wins over the base one, and `@TYPE` sets a different value per machine type.

## Steps Overview

1. Set the history length
2. Check the configuration

## Step 1: Set the history length

```conf
benchmark on
benchmark-history 20
```

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

A non-numeric `benchmark-history` is not reported there; Get-WorkspaceBenchmark stops with
"--last needs a number".

## Verification

```bash
Get-WorkspaceBenchmark
Get-WorkspaceBenchmark MyWorkspace --last 5
Get-WorkspaceBenchmark MyWorkspace --last 0
Get-WorkspaceBenchmark --source 20260101-100000
```

`--last 0` shows the whole history; `--source` shows the rows of one Measure-WorkspaceOpen session
(its id from `Measure-WorkspaceOpen --list-sessions`), which the everyday table leaves out.

## Complete Example

`Unix/config/workspaces.local.conf` (before its first section):

```conf
benchmark on
benchmark-history 20
@Laptop benchmark-history 5
```

## Related

- [`Get-WorkspaceBenchmark` in the Workflow module reference](../../modules/Workflow.md#get-workspacebenchmark)
- [Open-Workspace](Open-Workspace.md)
- [Measure-WorkspaceOpen](Measure-WorkspaceOpen.md)
- [Workflow configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
