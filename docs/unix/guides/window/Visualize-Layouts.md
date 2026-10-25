# Visualize-Layouts

Draws a workspace's layout desktop by desktop as boxes of its zone set with the windows assigned
to each zone, project variants included, and with `--update` writes the drawing into the layout
file.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`layouts/<Type>/<Workspace>_<Type>.conf`](../../configuration.md#layoutsworkdotfiles_workconf) | `[Workspace]`, `layout DESKTOP ZONESET`, `DESKTOP ZONE APP [TITLE]`, `monitor NAME`, `project A[,B...]` | the `Test` set | What is drawn: the workspaces of the set (the menu), each desktop's zone set and the windows in its zones, then every project variant whose projects exist |
| [`zones.conf`](../../configuration.md#zonesconf) | `ZONESET COLUMN...` | `Zero` to `Nine` | The box of a desktop: proportional columns, halved columns as two rows; `--display-available-layouts` draws every set |
| [`zones.conf`](../../configuration.md#zonesconf) | `alias ZONESET NAME ZONE` | `Full`, `Far-Left`, `Far-Right` | Second zone names a layout line may use |
| [`machines.conf`](../../configuration.md#files) | `layout-override TYPE OTHER`, `small-display TYPE`, `small-display-width POINTS` | none, none, `3000` | Which layout set is drawn without `--layout-type`, the same rules as Set-WorkspaceWindowLayout |
| [`machines.conf`](../../configuration.md#files) | `type NAME`, `host HOSTNAME TYPE`, `default TYPE` | `type Test`, `default Test` | The machine type, the layout set when neither rule above applies |
| [`projects.conf`](../../configuration.md#projectsconf) | `[Project]` | `[Dotfiles]` and `[ExampleProject]` | The projects a `project` variant may name; a variant naming another project is reported and not drawn, as Set-WorkspaceWindowLayout skips it |
| [`apps.conf`](../../configuration.md#files) | `app TOKEN ...`, `role NAME MEMBER...` | the base apps and the `Terminal` and `Browser` roles | The apps a layout line may name: a line naming neither a token nor a role makes the layout invalid, so it is reported and not drawn |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `layout-stable-ms N`, `layout-absent-grace-seconds N` | `500`, `10` | Nothing for the drawing: the layout library it loads reads them only while Set-WorkspaceWindowLayout waits for windows |

## Decisions

1. Which layout set should be drawn by default?
    - Options: the machine's own set from `machines.conf` (its type, `layout-override`, or `small-display` on a small panel); `--layout-type Laptop` draws another set for one run; `--layout-path FILE` draws every workspace of one file from anywhere (the Windows `-LayoutPath`; its set, for the backup key, is `--layout-type` or the name of the file's folder).
    - Default: this Mac's set, `Test` on a fresh clone. `--all` without `--layout-type` draws every workspace of every set (`--all --update` refreshes every set's drawings), as the Windows `-All` covers every machine type.
    - More detail: [`machines.conf`](../../configuration.md#files)
2. Which zone sets can a drawing use?
    - Options: every `ZONESET COLUMN...` line of `zones.conf` (base and overlay); a layout with an unknown set, a zone outside its desktop's set, a desktop without a `layout` line or an unknown app (in its base or in a variant that applies) is reported and neither drawn nor updated, and the exit status is 1, the checks Test-ConfigurationSchema runs.
    - Default: `Zero` to `Nine`.
    - More detail: [`zones.conf`](../../configuration.md#zonesconf)
3. Should layout files carry their drawing as comments?
    - Options: `--update` rewrites the block of `#|` comment lines right under each drawn section header, after backing the file up to `Backups/Unix/Config/WindowLayouts.<Type>.<Workspace>/<timestamp>/` (`--backup-root DIR`, the Windows `-BackupRoot`: `DIR/Config/...` instead); without it nothing is written.
    - Default: draw to the terminal only.
    - More detail: [`layouts/<Type>/<Workspace>_<Type>.conf`](../../configuration.md#layoutsworkdotfiles_workconf)

## Where to Put Values

Visualize-Layouts reads what Set-WorkspaceWindowLayout reads: the layout files of a fork's own
set folder, `Unix/config/layouts/<Type>/`, and `Unix/config/zones.local.conf`,
`Unix/config/machines.local.conf` and `Unix/config/projects.local.conf`, created when missing.
Lines before the first section are added after the base ones (for a single-value key the last
line wins), a `[Section]` replaces the base one whole, `-LINE` takes a base line back and `@TYPE`
limits a line to machine types. See
[Set-WorkspaceWindowLayout](Set-WorkspaceWindowLayout.md#where-to-put-values).

## Steps Overview

1. Write or change a layout
2. Draw it
3. Check the configuration

## Step 1: Write or change a layout

`Unix/config/layouts/Work/MyProject_Work.conf`:

```conf
[MyProject]
layout 1 Five
1 Left   Code      MyProject
1 Right  Terminal
project MyProjectApi
layout 1 One
1 Left   Code      MyProjectApi
1 Right  Browser
```

## Step 2: Draw it

```bash
Visualize-Layouts MyProject
Visualize-Layouts --all --layout-type Laptop
```

Without a name a menu of the set's workspaces is shown; `--layout MyProject` is the Windows
spelling of the name. `Visualize-Layouts --layout-path ~/Drafts/MyProject_Work.conf` draws a
file outside the layout sets. `Visualize-Layouts MyProject --update`
stores the drawing in the file once it looks right; it writes the file, so it is not a check.

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports unknown zone sets, zones outside their desktop's set and unknown apps, which the
drawing only warns about or draws anyway, and variants naming unknown projects, which the
drawing reports and leaves out.

## Verification

```bash
Test-ConfigurationSchema --quiet
Visualize-Layouts MyProject
Visualize-Layouts --display-available-layouts
```

## Complete Example

`Unix/config/zones.local.conf`:

```conf
Wide    Left:75 Right:25
alias Wide Main Left
```

`Unix/config/machines.local.conf`:

```conf
type Work
type Laptop
host My-Mac Work
small-display Laptop
small-display-width 2000
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

`Unix/config/projects.local.conf`, so the variant is drawn:

```conf
[MyProject]
path ROOT $DEV/MyProject

[MyProjectApi]
path ROOT $DEV/MyProject/src/MyProject.Api
```

## Related

- [`Visualize-Layouts` in the Window module reference](../../modules/Window.md#visualize-layouts)
- [Set-WorkspaceWindowLayout](Set-WorkspaceWindowLayout.md)
- [Window configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
