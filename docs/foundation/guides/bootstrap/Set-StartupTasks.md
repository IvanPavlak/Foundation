# Set-StartupTasks

Writes the LaunchAgent that makes macOS run the SignIn startup tasks of `startup.conf` when you sign
in, and removes it when no task needs it.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`startup.conf`](../../configuration.md#startupconf) | `trigger SignIn` in a `[Name]` section | none: the base ships no task | Whether the agent is needed: one valid, enabled task in this Mac's scope with the SignIn trigger writes it, none removes it |
| [`startup.conf`](../../configuration.md#startupconf) | `machine TYPE...`, `host NAME...`, `enabled off` | every Mac, enabled | Which tasks count on this Mac: a task out of scope or parked needs no agent |
| [`machines.conf`](../../configuration.md#files) | `host HOSTNAME TYPE` | none | This Mac's machine type, which the tasks' `machine` lines are matched against |

## Decisions

1. Should this Mac run tasks at sign-in?
    - Options: a task with `trigger SignIn` in `startup.local.conf`; the TerminalOpen trigger needs no agent (the shell rc runs it).
    - Default: no SignIn task, so no agent; a `foundation.StartupTasks-*` agent left from before is removed.
    - More detail: [Invoke-StartupTasks](../workflow/Invoke-StartupTasks.md)
2. Should Bootstrap keep the agent in step?
    - Options: `step StartupTasks on` or `off` in `bootstrap.local.conf`.
    - Default: on; the step registers nothing while no task has the SignIn trigger.
    - More detail: [Bootstrap a Mac](../../bootstrap.md#steps)

## Where to Put Values

The tasks go in `Unix/config/startup.local.conf` (see [Invoke-StartupTasks](../workflow/Invoke-StartupTasks.md));
this command has no file of its own. It keeps one agent per trigger in use, not one per task, and
the tasks are read when the agent fires, so an edited task needs no second run: run it again only
when the first SignIn task is added or the last one is removed (Bootstrap's StartupTasks step does).

## Steps Overview

1. Add a SignIn task
2. Write the agent
3. Try it without signing out
4. Check the configuration

## Step 1: Add a SignIn task

```conf
[MyWorkspace]
command   Open-Workspace MyWorkspace
trigger   SignIn
window    tab
```

A task started at sign-in cannot script other apps through Apple Events (macOS refuses the
Automation consent to an agent), so a task that drives AeroSpace windows or a browser needs
`window tab`.

## Step 2: Write the agent

```bash
Set-StartupTasks --dry-run
Set-StartupTasks
```

It writes `~/Library/LaunchAgents/foundation.StartupTasks-SignIn.plist`, which runs
`Invoke-StartupTasks --trigger SignIn` with no window, under Homebrew bash, its own output in
`.startup-agent-SignIn.log` in the log folder. The file is written, not loaded: macOS loads it at
the next sign-in, since loading it now would run the sign-in tasks at once. Running it again
changes nothing; `Set-StartupTasks --remove` removes every startup agent, whatever `startup.conf`
says.

## Step 3: Try it without signing out

Loading the agent runs the sign-in tasks at once:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/foundation.StartupTasks-SignIn.plist
launchctl print gui/$(id -u)/foundation.StartupTasks-SignIn
launchctl kickstart gui/$(id -u)/foundation.StartupTasks-SignIn
```

`print` shows the loaded agent and its last exit status; `kickstart` runs it again. A task with a
`frequency` that already ran is `NotDue`; delete its `.startup-task-NAME.stamp` in the log folder
to make it due. What the agent printed is in `.startup-agent-SignIn.log`, the task results in the
session log (see [Troubleshooting](../../troubleshooting.md#reading-what-the-sign-in-run-did)).

## Step 4: Check the configuration

```bash
Set-StartupTasks --list
Invoke-StartupTasks --trigger SignIn --dry-run
```

`--list` shows each agent with its state - `Registered`, `Outdated` (the file differs from what
would be written), `Missing` (a SignIn task needs it and it is not written) or `Stale` (nothing
needs it any more) - and whether launchd has it loaded.

## Verification

```bash
Set-StartupTasks --list
Set-StartupTasks --dry-run
Bootstrap --only StartupTasks --dry-run
Test-ConfigurationSchema --quiet
```

## Complete Example

`Unix/config/startup.local.conf`:

```conf
[RepositoryUpdate]
command   Update-Repositories --all --no-clone --quiet || true
trigger   SignIn TerminalOpen
requires  Network
frequency once-per-day
window    hidden

[MyWorkspace]
command   Open-Workspace MyWorkspace
trigger   SignIn
host      My-Mac
window    tab
```

`Unix/config/bootstrap.local.conf`:

```conf
step StartupTasks on
```

## Related

- [`Set-StartupTasks` in the Bootstrap module reference](../../modules/Bootstrap.md#set-startuptasks)
- [Invoke-StartupTasks](../workflow/Invoke-StartupTasks.md)
- [Bootstrap configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
