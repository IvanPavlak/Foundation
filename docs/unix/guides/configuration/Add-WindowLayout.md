# Add-WindowLayout

Creates a starting layout file for a workspace, `Unix/config/layouts/<TYPE>/<WORKSPACE>_<TYPE>.conf`,
in this machine's layout set or the sets named, for Set-WorkspaceWindowLayout to place windows by.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`layouts/<Type>/<Workspace>_<Type>.conf`](../../configuration.md#files) | `[Workspace]` | the `Test` set ships Default, Empty, Example, Fullscreen, SecureBrowser and Test | The file Add-WindowLayout creates, one per set; a workspace that already has a layout in that set is refused |
| [`layouts/<Type>/<Workspace>_<Type>.conf`](../../configuration.md#files) | `layout DESKTOP ZONESET` | written as `layout 1 Zero` | The zone set of a desktop (`zones.conf`) |
| [`layouts/<Type>/<Workspace>_<Type>.conf`](../../configuration.md#files) | `DESKTOP ZONE APP [TITLE]` | written as `1 Fullscreen Code` | One window: VS Code full screen on desktop 1, to customise |
| [`machines.conf`](../../configuration.md#files) | `layout-override TYPE OTHER` | none | Machine TYPE uses OTHER's layout set; picks the set when no `--machine-type` is given |
| [`machines.conf`](../../configuration.md#files) | `small-display TYPE`, `small-display-width POINTS` | no `small-display`; width `3000` | The set used when the primary display is at most that wide |
| [`machines.conf`](../../configuration.md#files) | `host HOSTNAME TYPE`, `default TYPE` | `default Test` | This machine's type, the set used otherwise |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `simple-layouts NAME...` | `simple-layouts Fullscreen Empty` | SimpleLayoutWorkspaces: `--simple` adds the workspace here (every window full size, none moved), writing the whole line to `workspaces.local.conf` |
| [`zones.conf`](../../configuration.md#zonesconf), [`workspaces.conf`](../../configuration.md#workspacesconf) | zone sets, the layout settings | the shipped zone sets; `layout-stable-ms 500` | Read by the layout library Add-WindowLayout loads; adding a layout uses neither, but the layout it writes is applied with them (see [Set-WorkspaceWindowLayout](../window/Set-WorkspaceWindowLayout.md)) |

## Decisions

1. Which layout sets should get the new layout?
    - Options: `--machine-type TYPE...` (several types, or `Work,Laptop`); a missing `layouts/<TYPE>/` folder is created, as on Windows. Name only `type` lines of `machines.conf`: Test-ConfigurationSchema reports a set folder that is no machine type. A workspace's layout must exist in every set a machine uses, so add it to each.
    - Default: this machine's layout set: its `layout-override`, else the `small-display` set on a small primary display, else its machine type.
    - More detail: [Layouts](../../configuration.md#files)
2. What should the layout place?
    - Options: edit the created file: `layout DESKTOP ZONESET` per desktop, `DESKTOP ZONE APP [TITLE]` per window, `project A,B` variants after the base lines.
    - Default: desktop 1 on zone set `Zero` with VS Code full screen.
    - More detail: [`zones.conf`](../../configuration.md#zonesconf)
3. Should a workspace apply it?
    - Options: a `Set-WorkspaceWindowLayout NAME` action in the workspace's `workspaces.conf` section (Add-Workspace writes it by default).
    - Default: a layout no workspace names is never applied.
    - More detail: [`workspaces.conf`](../../configuration.md#workspacesconf)
4. Should the workspace be a simple layout?
    - Options: `--simple` adds it to `simple-layouts` (also when its layout already existed): every window on every desktop full size, no window moved to another desktop, instead of the zones of its file.
    - Default: not simple; the shipped simple layouts are Fullscreen and Empty.
    - More detail: [Set-WorkspaceWindowLayout](../window/Set-WorkspaceWindowLayout.md)

## Where to Put Values

The layout file goes into the set folder itself, `Unix/config/layouts/<TYPE>/<WORKSPACE>_<TYPE>.conf`:
a fork's own sets (`Work/`, `Laptop/`) are its own files, and the `Test` set is the one a generic
clone ships. Add-WindowLayout never overwrites a layout file, and since it only creates new ones
it takes no backup for them. `--simple` writes the `simple-layouts` line to
`Unix/config/workspaces.local.conf` (the base value plus the workspace, before the overlay's first
section), backing the overlay up into `Backups/Unix/Config/` first. A `<WORKSPACE>_<TYPE>.local.conf` next to a
layout replaces its section. The `machines.conf` lines that choose the set go in
`Unix/config/machines.local.conf`.

## Steps Overview

1. Create the layout
2. Fill it in
3. Check the configuration

## Step 1: Create the layout

```bash
Add-WindowLayout MyProject --machine-type Work Laptop
```

Give the workspace name first: every word after `--machine-type` is taken as a type. For a
workspace whose windows only need to be full size, add `--simple`:

```bash
Add-WindowLayout MyNotes --simple
```

## Step 2: Fill it in

The created `Unix/config/layouts/Work/MyProject_Work.conf`:

```conf
[MyProject]
layout 1 Zero
1 Fullscreen   Code
```

edited into the layout you want:

```conf
[MyProject]
layout 1 Five
layout 2 One
1 Left    Code
1 Right   Terminal
2 Left    Browser   *MyProject*
2 Right   Code      MyProjectApi
```

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports a zone set missing from `zones.conf`, a zone not in its desktop's set, an app that is
no `apps.conf` token or role, a file whose section does not match its name, and a layout a
workspace names that is missing from a set some machine uses.

## Verification

```bash
Test-ConfigurationSchema --quiet
ls Unix/config/layouts/*/MyProject_*.conf
cat Unix/config/layouts/Work/MyProject_Work.conf
```

## Complete Example

`Unix/config/layouts/Work/MyProject_Work.conf`:

```conf
[MyProject]
layout 1 Five
layout 2 One
1 Left    Code
1 Right   Terminal
2 Left    Browser   *MyProject*
2 Right   Code      MyProjectApi
```

`Unix/config/workspaces.local.conf`, after `Add-WindowLayout MyNotes --simple`:

```conf
simple-layouts Fullscreen Empty MyNotes
```

`Unix/config/machines.local.conf`, the lines that choose the set:

```conf
type Work
type Laptop
host My-Mac Laptop
default Work
small-display Laptop
layout-override Test Work
```

## Related

- [`Add-WindowLayout` in the Configuration module reference](../../modules/Configuration.md#add-windowlayout)
- [Configuration configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
