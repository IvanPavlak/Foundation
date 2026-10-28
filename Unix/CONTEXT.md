# Domain Context

Names for the seams in this repository, so a review or a refactor reaches for the same word every
time. The terms follow WinuX's where the behaviour is the same; what differs on a Mac is said here.

## Unix half

Everything under `Unix/` and `docs/foundation/`, plus the few other paths `Unix/config/upstream.conf`
lists as `own`. Foundation is the Unix half as its own repository; WinuX is the Windows half. The
project documents (this file, the changelog, the versioning and contributing rules) live in `Unix/`;
the files of the same name at the repository root are generic pointers.

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

A fork can merge several projects (WinuX, Foundation) into one repository. Each project ships a
manifest (`upstream.conf`) naming its **rooms**, the `own` paths only it ships, and the **mirror**
files every project ships byte-identical. Everything else is the **hallway** (`README.md`,
`.github/`, `.gitignore`, the docs landing): it belongs to the **root owner**, the only upstream by
default, else the fork itself (`fork`), and a fork's `take` lines adopt single hallway paths from
one upstream (`Git/upstreams.local.conf`). `Merge-Upstreams NAME` applies those rules to a merge.
