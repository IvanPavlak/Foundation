# Set-WorkspaceWindowLayout

Waits for the windows a workspace's layout file names and tiles each desktop into the zones of
its zone set, the macOS twin of the Windows Set-WorkspaceWindowLayout.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`layouts/<Type>/<Workspace>_<Type>.conf`](../../configuration.md#layoutsworkdotfiles_workconf) | `[Workspace]` | the `Test` set: Default, Empty, Example, Fullscreen, SecureBrowser, Test | The layout of one workspace, one file per workspace and layout set, named after the section |
| [`layouts/<Type>/<Workspace>_<Type>.conf`](../../configuration.md#layoutsworkdotfiles_workconf) | `layout DESKTOP ZONESET` | none | The zone set of a desktop (an AeroSpace workspace, `alt-DESKTOP`); a desktop with windows but no `layout` line is skipped |
| [`layouts/<Type>/<Workspace>_<Type>.conf`](../../configuration.md#layoutsworkdotfiles_workconf) | `DESKTOP ZONE APP [TITLE]` | none | One window: an `apps.conf` token or a role (`Terminal`, `Browser`) placed in ZONE of DESKTOP; TITLE is exact, `*wildcard*` or regex and may contain spaces |
| [`layouts/<Type>/<Workspace>_<Type>.conf`](../../configuration.md#layoutsworkdotfiles_workconf) | `monitor NAME` | `Primary` | The monitor the following lines target; only `Primary` is placed yet, other entries are skipped with a warning |
| [`layouts/<Type>/<Workspace>_<Type>.conf`](../../configuration.md#layoutsworkdotfiles_workconf) | `project A[,B...]` | none | Opens a project variant up to the next `project` line: for an open of A or B its `layout` lines change those desktops' zone sets and its window lines replace every base window on the same desktop |
| [`zones.conf`](../../configuration.md#zonesconf) | `ZONESET COLUMN...` | `Zero` to `Nine` | A zone set: columns left to right, each `ZONE:PERCENT` (full height) or `TOP+BOTTOM:PERCENT` (two 50/50 rows) |
| [`aerospace.toml`](../../configuration.md#spacing-aerospacetoml) | `gaps.inner.horizontal`, `gaps.inner.vertical`, `gaps.outer.left`/`top`/`right`/`bottom` | `3` inner, `0` outer | The spacing between windows (inner) and at the work-area edges (outer), in points; the zones are sized and verified with whatever values the file sets |
| [`zones.conf`](../../configuration.md#zonesconf) | `alias ZONESET NAME ZONE` | `Full`, `Far-Left`, `Far-Right` | A second name for a zone |
| [`zones.conf`](../../configuration.md#zonesconf) | `parking-workspace NAME` | `P` | Where stray windows of a laid-out desktop are parked; `""` turns parking off |
| [`machines.conf`](../../configuration.md#files) | `layout-override TYPE OTHER` | none | Machine TYPE always uses OTHER's layout set; checked first |
| [`machines.conf`](../../configuration.md#files) | `small-display TYPE` | none | The layout set used when the primary display is at most `small-display-width` points wide |
| [`machines.conf`](../../configuration.md#files) | `small-display-width POINTS` | `3000` | The width (in points) at or below which a display counts as small |
| [`machines.conf`](../../configuration.md#files) | `type NAME`, `host HOSTNAME TYPE`, `default TYPE` | `type Test`, `default Test` | The machine type, which is the layout set when neither rule above applies |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `Set-WorkspaceWindowLayout NAME` (in a `[Workspace]` section) | one per base workspace (`Set-WorkspaceWindowLayout Example`) | When during an open the layout is applied, and which layout |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `simple-layouts NAME...` | `Fullscreen Empty` | Workspaces whose layout is a global gesture: every window on every desktop goes full size, none changes desktop |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `layout-early-move VALUE` | `off` | `on` moves each window to its desktop the moment it is claimed, instead of once all have appeared |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `layout-stable-ms N` | `500` (also without the line) | How long a claimed window's title must hold before it counts as ready; `FOUNDATION_STABLE_MS` overrides it |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `layout-absent-grace-seconds N` | `10` (also without the line) | After N seconds the wait gives up on an entry whose app is not running, or whose only matching windows belong to another workspace (or, alongside, existed before the open), instead of waiting the whole timeout; `0` always waits the timeout (the Windows `ProcessAbsentGraceSeconds`) |
| [`projects.conf`](../../configuration.md#projectsconf) | `[Project]` | `[Dotfiles]` and `[ExampleProject]` | The projects a `project` variant may name; a variant naming another project is reported and skipped |

## Decisions

1. Which workspaces need a layout, and on which machine types?
    - Options: one `<Workspace>_<Type>.conf` file per workspace in each layout set a machine uses (`layouts/Work/`, `layouts/Laptop/`); `Add-WindowLayout MyProject` creates a starting file.
    - Default: only the `Test` set ships; a workspace without a file in this machine's set opens without a layout (the command stops with "No [MyProject] layout").
    - More detail: [`layouts/<Type>/<Workspace>_<Type>.conf`](../../configuration.md#layoutsworkdotfiles_workconf)
2. Which zone set should each desktop use?
    - Options: a `layout DESKTOP ZONESET` line per desktop, ZONESET one of `zones.conf` (`Zero` full screen, `One` halves, `Five` 67.25/32.75, ...).
    - Default: none; a desktop with windows but no `layout` line is skipped with a warning.
    - More detail: [`zones.conf`](../../configuration.md#zonesconf)
3. Which window goes into which zone?
    - Options: `DESKTOP ZONE APP [TITLE]` lines; APP an `apps.conf` token or a role (`Terminal`, `Browser`); TITLE exact, `*wildcard*` or regex. Several lines in one zone are stacked, the last in front. `Get-ActiveWindowInfo` prints ready-made lines.
    - Default: none; a layout without window lines arranges nothing.
    - More detail: [`layouts/<Type>/<Workspace>_<Type>.conf`](../../configuration.md#layoutsworkdotfiles_workconf)
4. Should the layout differ per project?
    - Options: `project MyProject` (or `project A,B`) followed by `layout` and window lines; the projects must be `projects.conf` sections.
    - Default: no variants; the base layout applies to every open.
    - More detail: [`layouts/<Type>/<Workspace>_<Type>.conf`](../../configuration.md#layoutsworkdotfiles_workconf)
5. Do you need zone shares other than the shipped `Zero` to `Nine`?
    - Options: a `ZONESET COLUMN...` line with your own shares, `alias` lines for extra zone names.
    - Default: the ten FancyZones-shaped sets of the base file.
    - More detail: [`zones.conf`](../../configuration.md#zonesconf)
6. Where should windows that are not part of a desktop's layout go?
    - Options: `parking-workspace NAME`, any AeroSpace workspace name, or `""` to leave them in place (they then share the columns).
    - Default: `P` (`alt-p` shows it).
    - More detail: [`zones.conf`](../../configuration.md#zonesconf)
7. Which layout set should this Mac use?
    - Options: its machine type (`host` or `default` lines), `layout-override TYPE OTHER` to borrow another type's set, `small-display TYPE` with `small-display-width` for a laptop panel; for one run, `--layout-type TYPE`, or `--layout-path FILE` to apply a layout file from anywhere (its only workspace, or the one named; the Windows `-LayoutPath`).
    - Default: the machine type's own set (`Test` on a fresh clone).
    - More detail: [`machines.conf`](../../configuration.md#files)
8. Which workspaces should simply make every window full size instead of placing windows?
    - Options: `simple-layouts NAME...` in `workspaces.conf`.
    - Default: `Fullscreen Empty`.
    - More detail: [`workspaces.conf`](../../configuration.md#workspacesconf)
9. How fast should windows be claimed and moved?
    - Options: `layout-early-move on` to move each window as soon as it is claimed; `layout-stable-ms N` for how long a title must hold (lower is faster, too low can place a window before its title settled); `layout-absent-grace-seconds N` for how long to wait for an app that is not running before giving up on its window (0 waits the whole timeout).
    - Default: `layout-early-move off`, `layout-stable-ms 500`, `layout-absent-grace-seconds 10` from the base file. For one run, `--disable-auto-wait` (the Windows `-DisableAutoWait`) skips the wait: one look at the open windows, each entry takes what matches at once, and a window that is not there yet stays unplaced.
    - More detail: [`workspaces.conf`](../../configuration.md#workspacesconf)
10. How much space should be between windows and around them?
    - Options: the `gaps.inner.*` and `gaps.outer.*` lines of `Unix/aerospace/aerospace.toml`, any number of points each, a per-monitor list (`[{ monitor.main = 6 }, 3]`, the `monitor.main` value counts) included; 0 puts the windows edge to edge.
    - Default: 3 between windows (the spacing of the FancyZones layouts on Windows) and 0 at the screen edges, where a gap only takes space.
    - More detail: [Spacing](../../configuration.md#spacing-aerospacetoml)

## Where to Put Values

- Layouts: a fork's own set folder, `Unix/config/layouts/<Type>/`, one `<Workspace>_<Type>.conf`
  per workspace holding its `[Workspace]` section (the folder is a machine type of
  `machines.conf`). A `<Workspace>_<Type>.local.conf` next to a file replaces that section whole.
  The base `Test` set is what a generic clone ships; leave it as it is.
- `Unix/config/zones.local.conf`, `Unix/config/machines.local.conf`,
  `Unix/config/workspaces.local.conf` and `Unix/config/projects.local.conf`, created when missing.
  Lines before the first section (zone sets, `parking-workspace`, the `machines.conf` lines,
  `simple-layouts`, `layout-early-move`, `layout-stable-ms`, `layout-absent-grace-seconds`) are added after the base ones, and
  for a single-value key the last line wins; a `[Section]` replaces the base one whole; `-LINE`
  takes a base line back; `@TYPE` limits a line to machine types.

## Steps Overview

1. Map the Mac to a layout set
2. Create the layout file
3. Lay out the desktops
4. Add project variants
5. Adjust zones and timing
6. Check the configuration

## Step 1: Map the Mac to a layout set

`Unix/config/machines.local.conf`:

```conf
type Work
type Laptop
host My-Mac Work
default Laptop
small-display Laptop
small-display-width 2000
```

Use `layout-override Work Laptop` instead when one type should always borrow another's layouts.

## Step 2: Create the layout file

`Add-WindowLayout MyProject` writes `Unix/config/layouts/<Type>/MyProject_<Type>.conf` for this
machine's set (`--machine-type Work Laptop` for several). The workspace runs it with a
`Set-WorkspaceWindowLayout MyProject` line in its `workspaces.conf` section (Add-Workspace
writes that line by default).

## Step 3: Lay out the desktops

`Unix/config/layouts/Work/MyProject_Work.conf`:

```conf
[MyProject]
layout 1 Five
layout 2 One
1 Left   Code      MyProject
1 Right  Terminal
2 Left   Browser   *MyProject*
2 Right  Browser
```

An entry without a TITLE takes only windows no titled entry of the same app asks for; the only
untitled entry of an app takes every remaining window of it.

## Step 4: Add project variants

After the base lines, in the same section:

```conf
project MyProjectApi
layout 2 Six
2 Left          Code      MyProjectApi
2 Top-Right     Terminal
2 Bottom-Right  Browser
```

When the open is for `MyProjectApi` (`w MyProject MyProjectApi`), desktop 2 uses these lines
instead of the base ones. `MyProjectApi` must be a `projects.conf` section.

## Step 5: Adjust zones and timing

`Unix/config/zones.local.conf`:

```conf
Wide    Left:75 Right:25
alias Wide Main Left
parking-workspace P
```

`Unix/config/workspaces.local.conf`, before its first section:

```conf
layout-early-move on
layout-stable-ms 800
layout-absent-grace-seconds 5
```

## Step 6: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports a layout file whose section is not named after it, an unknown zone set, a zone that
is not in its desktop's set, an app that is not an `apps.conf` token or role, a variant naming
an unknown project, a layout a workspace names that is missing from a set some machine uses, and
a layout set that is not a `type` of `machines.conf`.

## Verification

```bash
Test-ConfigurationSchema --quiet
Visualize-Layouts MyProject
Visualize-Layouts MyProject --layout-type Laptop
Visualize-Layouts --display-available-layouts
```

Visualize-Layouts (without `--update`) only draws: each desktop's zone set with the windows in
its zones, then each project variant; a variant naming an unknown project is reported and not
drawn, as the layout skips it.

## Complete Example

`Unix/config/machines.local.conf`:

```conf
type Work
type Laptop
host My-Mac Work
default Laptop
small-display Laptop
small-display-width 2000
```

`Unix/config/zones.local.conf`:

```conf
Wide    Left:75 Right:25
alias Wide Main Left
parking-workspace P
```

`Unix/config/workspaces.local.conf`:

```conf
simple-layouts Fullscreen Empty
layout-early-move on
layout-stable-ms 800
layout-absent-grace-seconds 5

[MyProject]
Open-Project MyProject
Set-WorkspaceWindowLayout MyProject
Focus-VirtualDesktop 1
```

`Unix/config/projects.local.conf`:

```conf
[MyProject]
path ROOT $DEV/MyProject
action Open-VSCode MyProject

[MyProjectApi]
path ROOT $DEV/MyProject/src/MyProject.Api
action Open-VSCode MyProjectApi
```

`Unix/config/layouts/Work/MyProject_Work.conf`:

```conf
[MyProject]
layout 1 Wide
layout 2 One
1 Main   Code      MyProject
1 Right  Terminal
2 Left   Browser   *MyProject*
2 Right  Browser
project MyProjectApi
layout 2 Six
2 Left          Code      MyProjectApi
2 Top-Right     Terminal
2 Bottom-Right  Browser
```

`Unix/config/layouts/Laptop/MyProject_Laptop.conf` (every set a machine uses needs the layout;
here `default` and `small-display` map to `Laptop`):

```conf
[MyProject]
layout 1 Zero
layout 2 Zero
1 Fullscreen  Code      MyProject
1 Fullscreen  Terminal
2 Fullscreen  Browser
```

## Related

- [`Set-WorkspaceWindowLayout` in the Window module reference](../../modules/Window.md#set-workspacewindowlayout)
- [macOS Workspaces](../../macos-workspaces.md#what-happens-in-order)
- [Visualize-Layouts](Visualize-Layouts.md)
- [Window configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
