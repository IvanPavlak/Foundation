# Invoke-StartupTask

Runs one startup task - a task of `startup.conf` by name, or any command given with the same lines
as flags - with its gates, conditions, lock and stamp, here in this shell or in a tab of its own.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`startup.conf`](../../configuration.md#startupconf) | `[Name]` and its lines | none: the base ships no task | The task `Invoke-StartupTask NAME` runs when no `--command` is given; every line is a flag of this command (`frequency once-per-day` is `--frequency once-per-day`), and a flag given wins over the line |
| [`startup.conf`](../../configuration.md#startupconf) | `condition NAME [TIMEOUT [INTERVAL]] TEST` | `condition Network 60 2 route -n get default` | The conditions `requires` and `--requires` may name, also for a task given with `--command` |
| [`machines.conf`](../../configuration.md#files) | `host HOSTNAME TYPE` | none | This Mac's machine type, which `machine` and `--machine` are matched against |

## Decisions

1. Should the task come from `startup.conf` or from the command line?
    - Options: `Invoke-StartupTask NAME` runs the configured task (flags given override its lines); `Invoke-StartupTask NAME --command CMD ...` runs a one-off task from flags alone, with NAME naming its stamp and lock.
    - Default: the configured task of that name; without one and without `--command` the run fails and names the section to add.
    - More detail: [`startup.conf`](../../configuration.md#startupconf)
2. Where should it run?
    - Options: `--window current` (this shell), `tab` (a WezTerm tab in the `FoundationStartup` window) or `hidden` (a background process with no terminal); `--parallel` returns at once instead of waiting up to `--timeout`.
    - Default: `current`, whatever the task's `window` line says: the line is what the sign-in run of Invoke-StartupTasks uses.
    - More detail: [Invoke-StartupTasks](Invoke-StartupTasks.md)
3. Should it run although it already ran or is parked?
    - Options: `--force` passes the `enabled` and `frequency` gates, never the scope (`machine`, `host`); `--no-condition-wait` tests each condition once instead of waiting.
    - Default: a disabled task is `Disabled`, one that already ran is `NotDue`.
    - More detail: [`startup.conf`](../../configuration.md#startupconf)

## Where to Put Values

`Unix/config/startup.local.conf`, created when missing: a `[Name]` section per task, the
`condition` lines before the first section. A `[Task]` there replaces a base task of the same name
whole, `-LINE` takes a base line back, `@TYPE` limits a line to a machine type. The walkthrough of
every line is [Invoke-StartupTasks](Invoke-StartupTasks.md).

## Steps Overview

1. Define the task
2. Rehearse it
3. Run it by hand

## Step 1: Define the task

```conf
[MyUpdate]
command   Update-Repositories --all --no-clone --quiet || true
trigger   TerminalOpen
requires  Network
frequency once-per-day
```

The command line is run by bash with Foundation's PATH: the commands work, the aliases of the shell
rc do not. It has failed when it exits non-zero, and only a run that succeeded writes the stamp
(`.startup-task-MyUpdate.stamp` in the log folder) the frequency is measured from.

## Step 2: Rehearse it

```bash
Invoke-StartupTask MyUpdate --dry-run
```

It runs nothing and prints `WouldRun` (with the conditions it would wait for), or why not:
`Disabled`, `OutOfScope`, `NotDue`, or `Failed` with the problem of a task that is not valid.

## Step 3: Run it by hand

```bash
Invoke-StartupTask MyUpdate
Invoke-StartupTask MyUpdate --force
Invoke-StartupTask MyUpdate --window tab --keep-open always
Invoke-StartupTask OneOff --command 'Update-Repositories --group Private --no-clone --quiet' --requires Network
```

In order it checks the gates (Disabled, OutOfScope, NotDue), takes the task's lock (the same task
never runs twice at once: the second run is `AlreadyRunning`), waits for the `requires` conditions
(one not met makes it `Skipped`), asks `sudo` once with `--elevation prompt` (not with
`--window hidden`), and runs the command. It prints one line with the status and exits 1 when the
task Failed, was Skipped or TimedOut. A tab or hidden run is waited for up to `--timeout` seconds
(600; 0 without limit); the task is never stopped.

## Verification

```bash
Invoke-StartupTask MyUpdate --dry-run
Invoke-StartupTasks --trigger TerminalOpen --dry-run
Test-ConfigurationSchema --quiet
```

## Complete Example

`Unix/config/startup.local.conf`:

```conf
condition MyVpn 120 2 scutil --nc status MyVpn | grep -q '^Connected'

[MyUpdate]
command        Update-Repositories --all --no-clone --quiet || true
trigger        SignIn TerminalOpen
requires       Network
frequency      once-per-day
day-start-hour 6

[MyWorkspace]
command        Open-Workspace MyWorkspace
trigger        SignIn
host           My-Mac
requires       MyVpn
window         tab
keep-open      on-failure
```

## Related

- [`Invoke-StartupTask` in the Workflow module reference](../../modules/Workflow.md#invoke-startuptask)
- [Invoke-StartupTasks](Invoke-StartupTasks.md)
- [Workflow configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
