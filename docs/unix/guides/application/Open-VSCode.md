# Open-VSCode

Opens VS Code, one new window per named folder of `vscode-folders.conf`, skipping a folder that is
already open; without a folder it shows the folder menu.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`vscode-folders.conf`](../../configuration.md#files) | `NAME DIR` | `Dotfiles $DOTFILES_ROOT`, `ExampleProject $DEV/ExampleProject` | A folder Open-VSCode opens by name (any case); when several lines have the name the last one gives the folder, and the menu lists each name once, in file order |
| [`vscode-workspaces.conf`](../../configuration.md#files) | `default WORKSPACE NAME` | none | Read by Open-Workspace: during `w WORKSPACE`, Open-VSCode opens `NAME.code-workspace` through [Open-VSCodeWorkspace](Open-VSCodeWorkspace.md) instead of its folder |

## Decisions

1. Which folders should Open-VSCode know by name?
    - Options: one `NAME DIR` line per folder; `DIR` takes `~`, `$DEV` and `$DOTFILES_ROOT`, and must exist. A project's `Open-VSCode MyProject` action needs a `MyProject` line. Several folders of one project get one name each (`MyProject`, `MyProject-UI`).
    - Default: `Dotfiles`, the repository itself, and the showcase `ExampleProject` (`$DEV/ExampleProject`).
    - More detail: [`vscode-folders.conf`](../../configuration.md#files)
2. Should a workspace open a multi-root `.code-workspace` instead of the project folder?
    - Options: a `default WORKSPACE NAME` line in `vscode-workspaces.conf`, or `w WORKSPACE --vscode-workspace NAME` for one run.
    - Default: no `default` lines; Open-VSCode opens the folder.
    - More detail: [Open-VSCodeWorkspace](Open-VSCodeWorkspace.md)

## Where to Put Values

`Unix/config/vscode-folders.local.conf`, created when missing. The file has no sections: its lines
are added after the base ones, and for a name the last matching line wins, so an overlay line
redefines a base name (`Dotfiles ~/Other/Dotfiles`); `-LINE` takes a base line back. `@TYPE` limits a line to machine types
(`@Laptop MyProject ~/Projects/MyProject`).

## Steps Overview

1. Add the folder lines
2. Check the configuration

## Step 1: Add the folder lines

```conf
MyProject      $DEV/MyProject
MyProject-UI   $DEV/MyProject-ui
```

## Step 2: Check the configuration

```bash
grep -v '^#' Unix/config/vscode-folders.conf Unix/config/vscode-folders.local.conf
ls -d $DEV/MyProject $DEV/MyProject-ui
```

Every `DIR` must exist; a missing one is reported when it is opened.

## Verification

```bash
cat Unix/config/vscode-folders.local.conf
ls -d $DEV/MyProject $DEV/MyProject-ui
```

## Complete Example

`Unix/config/vscode-folders.local.conf`:

```conf
MyProject      $DEV/MyProject
MyProject-UI   $DEV/MyProject-ui
@Laptop MyNotes ~/Documents/MyNotes
```

## Related

- [`Open-VSCode` in the Application module reference](../../modules/Application.md#open-vscode)
- [Open-VSCodeWorkspace](Open-VSCodeWorkspace.md)
- [Application configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
