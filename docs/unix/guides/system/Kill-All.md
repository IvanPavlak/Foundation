# Kill-All

Closes everything: stops Docker, quits browsers, every app with a window and the named apps, then
closes the other terminal tabs, each part a step `kill-all.conf` turns on or off.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`kill-all.conf`](../../configuration.md#files) | `step NAME on\|off` | every step on except `MoveTerminal`, `CenterTerminal` and `ReloadProfile` | Whether a step runs by default; `--include` and `--skip` override it for one run, and a name that is no Kill-All step stops it before anything closes. A step with no line at all behaves like its base line |
| [`kill-all.conf`](../../configuration.md#files) | `keep TOKEN` | `Terminal`, `Finder`, `AeroSpace` | Apps the VisibleWindows step never quits and the survivor report leaves out: an `apps.conf` token, a role (`Terminal`, `Browser`) or an app name as AeroSpace reports it. The `Terminal` role and Finder survive without a line too; no `keep` line at all makes the step warn and quit nothing, as on Windows |
| [`kill-all.conf`](../../configuration.md#files) | `quit TOKEN` | `Code` | What the NamedProcesses step always quits: an `apps.conf` token, else a bundle id, else a process by its exact name (a daemon or helper with no app, ended with `pkill`, then `pkill -9` after 5 s); no `quit` line at all is a warning |
| [`docker.conf`](../../configuration.md#dockerconf) | `timeout stop SECONDS` | `60` | How long the Docker step waits for Docker Desktop to quit before killing it (60 without a line too) |

The steps run in this order: VirtualDesktops, Docker, Browsers, VisibleWindows, NamedProcesses,
TerminalTabs, MoveTerminal, CenterTerminal, FocusTerminal, ReloadProfile. VirtualDesktops only
focuses desktop 1 (AeroSpace workspaces vanish when emptied), and ReloadProfile only prints how
to reload the shell (`Reload-Profile`). CenterTerminal sizes the
window through Center-Terminal, which reads `window.conf` itself. The browsers quit are the
members of the `Browser` role of `apps.conf`, a shared file. A browser is never killed, as on
Windows: one still running after two quit requests (4 s, then 2 s) is named in a warning and left
running, because it is holding a dialog. Other apps that ignore Cmd+Q are killed after 5 s.

## Decisions

1. Which steps should a plain `Kill-All` run?
    - Options: one `step NAME on|off` line per step to change (names case-insensitive); the last line wins. Turning Docker off leaves containers running; MoveTerminal moves the terminal to desktop 1; CenterTerminal floats it centered instead of tiled; ReloadProfile only prints how to reload the shell.
    - Default: the base lines: every step on except MoveTerminal, CenterTerminal and ReloadProfile. The survivor audit and the clearing of the Close-Workspace record need Browsers, VisibleWindows and NamedProcesses all on.
    - More detail: [`kill-all.conf`](../../configuration.md#files)
2. Which apps with windows should always survive?
    - Options: `keep TOKEN` lines, one per app or role (`keep Obsidian`, `keep Slack`). Finder and the terminal (`Terminal` role, the process running Kill-All) always survive; taking back every `keep` line makes VisibleWindows quit nothing, with a warning.
    - Default: the terminal (`Terminal` role), Finder and AeroSpace.
    - More detail: [`kill-all.conf`](../../configuration.md#files)
3. Which apps should be quit even without a window?
    - Options: `quit TOKEN` lines, one per app (`quit Docker`, `quit Discord`) or windowless process by its exact name (`quit VBoxSVC`).
    - Default: `quit Code`.
    - More detail: [`kill-all.conf`](../../configuration.md#files)
4. How long should the Docker step wait for Docker Desktop to quit?
    - Options: `timeout stop SECONDS` in `docker.conf`; after it, Docker Desktop is killed.
    - Default: 60 seconds in the base file.
    - More detail: [`docker.conf`](../../configuration.md#dockerconf)

## Where to Put Values

`Unix/config/kill-all.local.conf` and `Unix/config/docker.local.conf`, created when missing.
Neither file has sections here: the overlay's lines are added after the base lines. A later
`step` line for the same step wins, and the last `timeout stop` line wins, so an overlay line
overrides the base; `keep` and `quit` lines add to the base ones, and `-LINE` takes one back
(`-quit Code`). `@TYPE` limits a line to machine types.

## Steps Overview

1. Set the steps
2. Add the keep and quit apps
3. Set the Docker timeout
4. Check the configuration

## Step 1: Set the steps

```conf
step Docker        off
step MoveTerminal  on
```

## Step 2: Add the keep and quit apps

Name apps by their `apps.conf` token.

```conf
keep Obsidian
quit Discord
-quit Code
```

## Step 3: Set the Docker timeout

In `Unix/config/docker.local.conf`:

```conf
timeout stop 30
```

## Step 4: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `@TYPE` prefix that names a machine type `machines.conf` does not have; it does not
check the step names or the tokens.

## Verification

```bash
Test-ConfigurationSchema --quiet
cat Unix/config/kill-all.local.conf
grep -n 'timeout' Unix/config/docker.conf Unix/config/docker.local.conf
```

## Complete Example

`Unix/config/kill-all.local.conf`:

```conf
step Docker        off
@Work step Docker  on
step MoveTerminal  on
keep Obsidian
quit Discord
-quit Code
```

`Unix/config/docker.local.conf`:

```conf
timeout stop 30
```

## Related

- [`Kill-All` in the System module reference](../../modules/System.md#kill-all)
- [System configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
