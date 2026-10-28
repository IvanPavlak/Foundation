# Add-Workspace

Adds a workspace as a new `[NAME]` section of `workspaces.local.conf`: its own action lines, or a
template instance of `workspace-templates.conf` that `w NAME` opens.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `[Workspace]` | Example, Test, Fullscreen, Empty, Default, SecureBrowser | The workspace; Add-Workspace writes the section and refuses a name already in the base file or the overlay |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `ACTION ARGS...` | per base workspace | One action, written for each `--action "LINE"`; without any, `Set-WorkspaceWindowLayout NAME` |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `template NAME` | none | Written for `--template NAME`: the section stamps out that template instead of listing actions |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `set NAME VALUE...` | none | A template variable, written for each `--set NAME=VALUE` |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `add LINE` | none | With `--template`, each `--action "LINE"` is written as `add LINE`: just before the template's first `Set-WorkspaceWindowLayout` |
| [`workspace-templates.conf`](../../configuration.md#workspace-templatesconf) | `[Template]` | none (a commented example) | The templates `--template` may name; an unknown one is refused, with the list of the defined ones |

## Decisions

1. What is the workspace called?
    - Options: any name without `[` or `]`, opened with `w NAME`; `{Workspace}` in its lines and template defaults expands to it.
    - Default: none; the first plain argument (or `--name NAME`). A name already in the base file or the overlay is refused and nothing is written.
    - More detail: [`workspaces.conf`](../../configuration.md#workspacesconf)
2. Should it list its own actions or stamp out a template?
    - Options: `--action "LINE"` per action (a Foundation command with its arguments, an `Open-<App>` of `apps.conf`, or `Return`), quoted; or `--template NAME` for a template of `workspace-templates.conf`.
    - Default: a single `Set-WorkspaceWindowLayout NAME` action.
    - More detail: [`workspace-templates.conf`](../../configuration.md#workspace-templatesconf)
3. Which template variables does it set?
    - Options: `--set NAME=VALUE` per variable (only with `--template`); a variable without a default in the template must be set.
    - Default: the template's own defaults.
    - More detail: [`workspace-templates.conf`](../../configuration.md#workspace-templatesconf)
4. Should a template instance replace or drop template actions?
    - Options: `replace KEY LINE`, `drop KEY` and `add before|after KEY LINE` lines, added to the section by hand; Add-Workspace only writes bare `add` lines.
    - Default: the template's actions as they are.
    - More detail: [`workspace-templates.conf`](../../configuration.md#workspace-templatesconf)

## Where to Put Values

`Unix/config/workspaces.local.conf`, created with a header when missing and backed up into
`Backups/Unix/Config/` before every later write (nothing is written when the backup fails).
Add-Workspace only appends new sections; a `[Default]` written there by hand replaces the base one
whole. Templates go in `Unix/config/workspace-templates.local.conf`, whose sections replace a
same-named template whole. `@TYPE` limits a line to machine types, `+A,B` to projects.

## Steps Overview

1. Add the workspace
2. Check the configuration

## Step 1: Add the workspace

With its own actions:

```bash
Add-Workspace MyProject --action "Open-Project MyProject" --action "Open-Browser MyGroup" --action "Set-WorkspaceWindowLayout MyProject"
```

```conf
[MyProject]
Open-Project MyProject
Open-Browser MyGroup
Set-WorkspaceWindowLayout MyProject
```

Or as a template instance:

```bash
Add-Workspace MyProject --template Project --set Repository=MyRepo --action "Open-Obsidian --workspace MyProject"
```

```conf
[MyProject]
template Project
set Repository MyRepo
add Open-Obsidian --workspace MyProject
```

`Set-WorkspaceWindowLayout MyProject` needs a layout ([Add-WindowLayout](Add-WindowLayout.md)).

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an unknown template or variable, an action that is no command, `Open-<App>` or
`Return`, an `Open-Project` or `Open-Browser` naming nothing, and a layout missing from a set a
machine uses.

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n -A4 '^\[MyProject\]' Unix/config/workspaces.local.conf
```

## Complete Example

`Unix/config/workspace-templates.local.conf`:

```conf
[Project]
var Repository {Workspace}Repository
Open-Project {Workspace}
Open-Browser {Repository} AI
Set-WorkspaceWindowLayout {Workspace}
Focus-VirtualDesktop 1
```

`Unix/config/workspaces.local.conf`:

```conf
[MyProject]
template Project
set Repository MyRepo
add Open-Obsidian --workspace MyProject

[Research]
Open-Browser MyGroup
@Laptop Open-Obsidian
Set-WorkspaceWindowLayout Research
```

## Related

- [`Add-Workspace` in the Configuration module reference](../../modules/Configuration.md#add-workspace)
- [Configuration configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
