# Invoke-StartupTasks

Runs the startup tasks of `startup.conf` that have one trigger - at sign-in (through the LaunchAgent
Set-StartupTasks writes) or in a newly opened terminal (through the shell rc) - and is the page that
walks through setting startup tasks up.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`startup.conf`](../../configuration.md#startupconf) | `failure-report tab\|none` | `tab` | Whether one terminal tab lists the tasks that failed, were skipped or timed out after a sign-in run |
| [`startup.conf`](../../configuration.md#startupconf) | `condition NAME [TIMEOUT [INTERVAL]] TEST` | `condition Network 60 2 route -n get default` | A named test a task can require: a bash command line, met when it exits 0, tried every INTERVAL seconds (2) for up to TIMEOUT seconds (60; 0 tests once) |
| [`startup.conf`](../../configuration.md#startupconf) | `[Name]` | none: the base ships no task | One task, run in the order written; letters, digits, `-` and `_` |
| [`startup.conf`](../../configuration.md#startupconf) | `command CMD` | none: the task only opens a terminal | The command line, run by bash with Foundation's PATH (the aliases of the shell rc do not work); the task has failed when it exits non-zero |
| [`startup.conf`](../../configuration.md#startupconf) | `trigger SignIn\|TerminalOpen` | required | When it runs: at sign-in, in a newly opened terminal, or both. `Unlock`, `Wake` and `Boot` are rejected |
| [`startup.conf`](../../configuration.md#startupconf) | `machine TYPE...`, `host NAME...` | every machine type and host | The Macs it runs on; with both, both must match |
| [`startup.conf`](../../configuration.md#startupconf) | `requires CONDITION...` | none | The conditions it waits for before the command (a terminal-open run tests them once) |
| [`startup.conf`](../../configuration.md#startupconf) | `window tab\|hidden` | `tab` | Where a sign-in run happens: a WezTerm tab in the `FoundationStartup` window, or a process with no terminal. A terminal-open run is always inline |
| [`startup.conf`](../../configuration.md#startupconf) | `keep-open on-failure\|always\|never` | `on-failure` (`always` without a command) | Whether the task's tab stays open after it |
| [`startup.conf`](../../configuration.md#startupconf) | `parallel on` | off | The sign-in run starts the task and goes on without waiting for it |
| [`startup.conf`](../../configuration.md#startupconf) | `frequency every-time\|once-per-boot\|once-per-day\|interval` | `every-time` | How often it runs; only a successful run counts |
| [`startup.conf`](../../configuration.md#startupconf) | `day-start-hour N`, `interval-hours N` | `6`, `24` | The hour a new day starts (once-per-day); the hours between two successful runs (interval) |
| [`startup.conf`](../../configuration.md#startupconf) | `elevation prompt` | none | `sudo` asks once in the task's tab before the command; not with `window hidden` or the TerminalOpen trigger |
| [`startup.conf`](../../configuration.md#startupconf) | `timeout SECONDS` | `600` | How long the sign-in run waits for the task before it moves on (0 without limit); the task is never stopped |
| [`startup.conf`](../../configuration.md#startupconf) | `enabled off` | on | Parks the task |
| [`machines.conf`](../../configuration.md#files) | `host HOSTNAME TYPE` | none | This Mac's machine type, which `machine` lines and `@TYPE` prefixes are matched against |

## Decisions

1. What should run on its own, and when?
    - Options: one `[Name]` section per task with a `command` line and one or both triggers: `SignIn` (when you sign in, through a LaunchAgent) and `TerminalOpen` (in the first terminal that finds the task due).
    - Default: nothing; the base ships no task.
    - More detail: [`startup.conf`](../../configuration.md#startupconf)
2. Does a task need something first, such as a network or a VPN?
    - Options: a `condition NAME [TIMEOUT [INTERVAL]] TEST` line before the first section and a `requires NAME` line in the task; the base `Network` condition is met when a default route exists and sends nothing anywhere.
    - Default: no condition; the task runs at once.
    - More detail: [`startup.conf`](../../configuration.md#startupconf)
3. Which Macs should run the task?
    - Options: `machine TYPE...` (the machine types of `machines.conf`), `host NAME...` (host names), or both; an `@TYPE` prefix limits a single line.
    - Default: every Mac that has the file.
    - More detail: [Shared format](../../configuration.md#shared-format)
4. Where should a sign-in task run?
    - Options: `window tab`, a WezTerm tab in the `FoundationStartup` window (needed for a task that drives AeroSpace or a browser, or asks for `sudo`), or `window hidden`, a process with no terminal; `keep-open` decides whether the tab stays, `parallel on` lets the next task start at once.
    - Default: a tab that closes when the task succeeded, the tasks one after the other.
    - More detail: [Troubleshooting: Startup tasks](../../troubleshooting.md#a-sign-in-task-cannot-control-another-app)
5. How often should the task run?
    - Options: `frequency every-time`, `once-per-boot`, `once-per-day` (with `day-start-hour`), or `interval` (with `interval-hours`). Only a run that succeeded counts, so a failed or skipped task is due again at the next trigger.
    - Default: every time its trigger fires.
    - More detail: [`startup.conf`](../../configuration.md#startupconf)
6. Should a sign-in run that went wrong open a report?
    - Options: `failure-report tab` or `failure-report none` before the first section.
    - Default: `tab`: one terminal tab lists the tasks that failed, were skipped or timed out.
    - More detail: [`startup.conf`](../../configuration.md#startupconf)

## Where to Put Values

`Unix/config/startup.local.conf`, created when missing. Its lines before the first section are
added to the base ones (a condition of yours joins `Network`), a `[Task]` there replaces a base
task of the same name whole, `-LINE` takes a base line back, and `@TYPE` limits a line to a machine
type. The file is read at every run, so an edited task takes effect at the next trigger; only the
first SignIn task (or the removal of the last one) needs [Set-StartupTasks](../bootstrap/Set-StartupTasks.md)
to run again.

## Steps Overview

1. Add a first task
2. Add a condition
3. Choose the scope
4. Choose the window of a sign-in task
5. Choose the frequency
6. Choose the failure report
7. Rehearse with --dry-run
8. Register the sign-in agent
9. Move the old repository update

## Step 1: Add a first task

A task is a section with a command and a trigger. The command line is run by bash with
Foundation's PATH, so every Foundation command works, but the aliases of the shell rc (`w`, `cw`)
do not: write the command's name.

```conf
[RepositoryUpdate]
command   Update-Repositories --all --no-clone --quiet || true
trigger   TerminalOpen
```

`TerminalOpen` runs the task inline in a newly opened terminal, before the first prompt, and in a
shell left open overnight at its first prompt after a new day starts (for a once-per-day task). It
does not run in the tabs a workspace open spawns, nor in a shell a startup task runs in. `SignIn`
runs it when you sign in, through the LaunchAgent of Step 8; a task may have both
(`trigger SignIn TerminalOpen`). Nothing runs before you sign in.

A task has failed when its command exits non-zero, and a failed task is due again at the next
trigger: `Update-Repositories` exits 1 when a repository needs attention, so `|| true` keeps that
from making every new terminal retry the update.

## Step 2: Add a condition

A condition is a named test before the first section; a task waits for it with `requires`:

```conf
condition MyVpn 120 2 scutil --nc status MyVpn | grep -q '^Connected'

[MyWorkspace]
command   Open-Workspace MyWorkspace
trigger   SignIn
requires  Network MyVpn
```

TEST is a bash command line, met when it exits 0 (its output is not shown), tried every INTERVAL
seconds until it is met or TIMEOUT seconds have passed. A sign-in run waits; a terminal-open run
tests once and, when the condition is not met, skips the task silently: a new shell tries it again
after 300 seconds, so an offline Mac does not start a process in every shell. A task that requires
a name with no `condition` line is not valid and never runs.

## Step 3: Choose the scope

```conf
[MyWorkspace]
command   Open-Workspace MyWorkspace
trigger   SignIn
machine   Work Laptop
host      My-Mac
```

`machine` names machine types of `machines.conf`, `host` host names; with both, both must match.
Out of scope the task is `OutOfScope` and needs no agent.

## Step 4: Choose the window of a sign-in task

A sign-in task runs in a WezTerm tab of the `FoundationStartup` window (`window tab`, the default)
or in a process with no terminal (`window hidden`), its output in the session log. A hidden task
cannot script other apps through Apple Events (macOS refuses the Automation consent to a process
started at sign-in), so a task that drives AeroSpace or a browser, such as `Open-Workspace`, needs
a tab. `elevation prompt` asks `sudo` once in the tab before the command; it needs a tab and is not
allowed with the TerminalOpen trigger.

```conf
[RepositoryUpdate]
command   Update-Repositories --all --no-clone --quiet || true
trigger   SignIn
window    tab
keep-open always
parallel  on
timeout   900
```

`keep-open on-failure` (the default) closes the tab when the task succeeded, `always` leaves it,
`never` always closes it. The sign-in run waits for each task before it starts the next, up to its
`timeout`; a `parallel on` task is started and collected at the end. One task failing never stops
the next. A terminal-open run ignores `window`, `parallel` and `timeout`: it is always inline.

## Step 5: Choose the frequency

```conf
[RepositoryUpdate]
command        Update-Repositories --all --no-clone --quiet || true
trigger        SignIn TerminalOpen
frequency      once-per-day
day-start-hour 5

[Backup]
command        my-backup-script
trigger        SignIn
frequency      interval
interval-hours 12
```

`every-time` (the default) runs at every trigger, `once-per-boot` once per start of the Mac,
`once-per-day` once per day, a day starting at `day-start-hour` (6 without a line, so a terminal
opened past midnight still counts as the day before), `interval` once per `interval-hours`. Only a
run that succeeded writes the task's stamp (`.startup-task-NAME.stamp` in the log folder), so a
task that failed or was skipped is due again. Between runs a new shell reads one gate file and
starts no process until a terminal-open task is due.

## Step 6: Choose the failure report

```conf
failure-report none
```

After a sign-in run in which a task failed, was skipped or timed out, one terminal tab lists them
(`tab`, the default); `none` leaves only the session log. A task that is not valid (an unknown
key or value, a missing trigger, a `requires` with no condition) is reported at every run and never
started.

## Step 7: Rehearse with --dry-run

```bash
Invoke-StartupTasks --trigger SignIn --dry-run
Invoke-StartupTasks --trigger TerminalOpen --dry-run
Invoke-StartupTask RepositoryUpdate --dry-run
```

The rehearsal runs nothing and lists, per task, what would happen now: `WouldRun` (with the
conditions it would wait for), `NotDue`, `OutOfScope`, `Disabled`, or `Failed` with the reason for
a task that is not valid. `Test-ConfigurationSchema --quiet` checks an `@TYPE` prefix.

## Step 8: Register the sign-in agent

A SignIn task needs the LaunchAgent [Set-StartupTasks](../bootstrap/Set-StartupTasks.md) writes
(Bootstrap's StartupTasks step runs it). macOS loads it at the next sign-in; the guide of
Set-StartupTasks shows how to load and run it now. A TerminalOpen task needs no agent.

```bash
Set-StartupTasks --dry-run
Set-StartupTasks
```

## Step 9: Move the old repository update

The `startup`, `startup-schedule`, `startup-day-start-hour`, `startup-interval-hours` and
`startup-scope` lines of `repositories.conf` and the command behind them are gone; the update is a
startup task. Take the old lines out of `repositories.local.conf` and write one task per old scope:

| Old line of `repositories.conf` | Task line of `startup.local.conf` |
| --- | --- |
| `startup on` | a `[RepositoryUpdate]` section with `trigger TerminalOpen` (add `SignIn` to update at sign-in too) and `requires Network` |
| `startup-scope All` | `command Update-Repositories --all --no-clone --quiet \|\| true` |
| `@Laptop startup-scope Private Work` | a task of its own with `machine Laptop` and `command Update-Repositories --group Private Work --no-clone --quiet \|\| true`; the `All` task gets `machine` lines for the other types |
| `startup-schedule daily` | `frequency once-per-day` |
| `startup-day-start-hour 5` | `day-start-hour 5` (not needed for 6) |
| `startup-schedule interval`, `startup-interval-hours 12` | `frequency interval`, `interval-hours 12` |

Without a `startup-scope` line the old update took the `repository-scope` of `bootstrap.conf`; a
task names its groups in its command. `FOUNDATION_STARTUP_SKIP=StartupTasks` (once
`RepositoryUpdate`) leaves the stage out for one shell. Then run the rehearsal of Step 7.

## Verification

```bash
Invoke-StartupTasks --trigger SignIn --dry-run
Invoke-StartupTasks --trigger TerminalOpen --dry-run
Invoke-StartupTask MyWorkspace --dry-run
Set-StartupTasks --list
Test-ConfigurationSchema --quiet
```

None of them runs a task or changes the Mac. `Set-StartupTasks --list` shows whether the sign-in
agent is written (`Registered`) and loaded.

## Complete Example

`Unix/config/startup.local.conf`:

```conf
failure-report tab
condition MyVpn 120 2 scutil --nc status MyVpn | grep -q '^Connected'

[RepositoryUpdate]
command        Update-Repositories --all --no-clone --quiet || true
trigger        SignIn TerminalOpen
machine        Work Laptop
requires       Network
frequency      once-per-day
window         tab
keep-open      always
parallel       on

[RepositoryUpdateTest]
command        Update-Repositories --group Private --no-clone --quiet || true
trigger        SignIn TerminalOpen
machine        Test
requires       Network
frequency      once-per-day
window         hidden

[MyWorkspace]
command        Open-Workspace MyWorkspace
trigger        SignIn
host           My-Mac
requires       Network MyVpn
window         tab
timeout        300

[Upgrade]
command        Upgrade-All
trigger        SignIn
frequency      interval
interval-hours 168
elevation      prompt
keep-open      always
enabled        off
```

## Related

- [`Invoke-StartupTasks` in the Workflow module reference](../../modules/Workflow.md#invoke-startuptasks)
- [Invoke-StartupTask](Invoke-StartupTask.md)
- [Set-StartupTasks](../bootstrap/Set-StartupTasks.md)
- [Troubleshooting: Startup tasks](../../troubleshooting.md#startup-tasks)
- [Workflow configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
