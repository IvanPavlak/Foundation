# Domain Context

Names for the seams in this repository, so a review or a refactor reaches for the same word every
time. The terms follow WinuX's where the behaviour is the same; what differs on a Mac is said here.

## Unix half

Everything under `Unix/` and `docs/unix/`, plus the few root paths `Unix/config/upstream.conf`
lists as `own`. Foundation is the Unix half as its own repository; WinuX is the Windows half.

## Command

An executable `Unix/modules/<Module>/bin/<Verb-Noun>`, listed by a `command` line of its module's
`module.conf`. It is its own process: nothing it sets outlives it, so there is no session state to
reset and no rerun-in-a-fresh-shell as on Windows. A **helper** is an undocumented executable of a
module (`helper` line); the Windows aliases (`w`, `cw`, `b`) are shell functions of the shared rc.

## Driver

The one file that invokes a platform tool: `Unix/lib/drivers/aerospace.sh` (windows, workspaces,
tiling), `wezterm.sh` (tabs and panes), `browserscript.sh` (browser windows and tabs),
`inputsource.sh` (keyboard layouts). Everything else asks a driver, so a Linux driver can replace
one without touching a command.

## Base and overlay

Every config file `NAME.conf` ships the generic **base**; its `NAME.local.conf` **overlay** holds a
fork's values. The readers of `Unix/lib/config.sh` layer them: overlay lines before the first
section are added, an overlay `[Section]` replaces the base one whole, `-LINE` takes a base line
back. Writers only ever write the overlay.

## Machine type

The `{MachineType}` of WinuX: a name from the `type` lines of `machines.conf`, picked by the
hostname (`host` lines), else the `default`. A line of any file that starts with `@TYPE` applies on
that type only. The base ships `Test` alone; a fork adds its own. The **layout set** is the folder
of `Unix/config/layouts/` a machine uses, its type unless `layout-override` names another.

## Workspace

A named list of actions in `workspaces.conf` (or a `template` of `workspace-templates.conf` stamped
out under the workspace's name) that `Open-Workspace` runs and `Close-Workspace` reverses. A plain
open owns the screen; an **alongside** open adds itself on further desktops without touching what is
there. The **ownership record** (`$XDG_STATE_HOME/foundation`, through `Unix/lib/state.sh`) is the
only source of truth for what an open owns: the windows and panes it created plus the windows its
layout adopted.

## Layout

`layouts/<Set>/<Workspace>_<Set>.conf`: which window goes on which desktop and zone. AeroSpace
workspaces `1`..`9` are the virtual desktops and its tiling tree is the zone layout; placement is
imperative (ADR 0001): the driver moves and sizes windows at open time, with no standing window
rules. A **zone set** (`zones.conf`) names the column shares of a desktop.

## Bootstrap step

One switchable unit of `Bootstrap` (`Homebrew`, `Packages`, `Dotfiles`, `SystemDefaults`, ...),
turned on or off per machine in `bootstrap.conf`; every step is safe to rerun. `Unix/bootstrap.sh`
is the first run before Homebrew bash exists: it links the dotfiles with chezmoi, whose first apply
hands over to `Bootstrap --with-initial-setup`.

## Custom area

`Unix/modules/Custom/<Module>/`: a fork's own commands, laid out like an engine module and never
written by upstream. The engine wins a name clash.

## Path ownership

For a fork of both WinuX and Foundation, every path has one upstream: **own** paths come from
Foundation, **mirror** paths are WinuX files Foundation ships unchanged, everything else comes from
WinuX. `Merge-Upstream --owned-only` applies that split to a merge.
