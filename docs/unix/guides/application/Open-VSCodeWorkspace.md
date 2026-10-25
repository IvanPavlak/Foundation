# Open-VSCodeWorkspace

Opens VS Code multi-root workspaces (`*.code-workspace`) by file base name from the `directory` of
`vscode-workspaces.conf`, skipping one that is already open; without a name it shows a menu.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`vscode-workspaces.conf`](../../configuration.md#files) | `directory PATH` | `$DOTFILES_ROOT/VSCode/Workspaces` | The folder of `*.code-workspace` files; `NAME` opens `NAME.code-workspace` there |
| [`vscode-workspaces.conf`](../../configuration.md#files) | `default WORKSPACE NAME` | none | Read by Open-Workspace: `w WORKSPACE` routes its `Open-VSCode` action here to open `NAME.code-workspace` instead of the project folder |

## Decisions

1. Where do the `.code-workspace` files live?
    - Options: `directory PATH`; `~`, `$DEV` and `$DOTFILES_ROOT` expand. The folder must exist and hold at least one `*.code-workspace` file.
    - Default: `$DOTFILES_ROOT/VSCode/Workspaces`.
    - More detail: [`vscode-workspaces.conf`](../../configuration.md#files)
2. Should a Foundation workspace open a multi-root workspace instead of its project folder?
    - Options: one `default WORKSPACE NAME` line per workspace (`default MyProject MyProject` opens `MyProject.code-workspace` during `w MyProject`), or `w WORKSPACE --vscode-workspace NAME` for one run; a bare `--vscode-workspace` shows the menu.
    - Default: no `default` lines; the workspace's `Open-VSCode` opens the folder.
    - More detail: [`vscode-workspaces.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/vscode-workspaces.local.conf`, created when missing. The file has no sections: its
lines are added after the base ones, the last `directory` line for this machine type wins, and
`default` lines add up. `@TYPE` limits a line to machine types (`@Work default MyProject MyProject`).
The `.code-workspace` files themselves go in the `directory`.

## Steps Overview

1. Set the workspaces folder
2. Add the default lines
3. Check the configuration

## Step 1: Set the workspaces folder

Only when it is not `$DOTFILES_ROOT/VSCode/Workspaces`:

```conf
directory $DEV/MyRepo/.vscode/workspaces
```

## Step 2: Add the default lines

```conf
default MyProject MyProject
```

`MyProject` must be a section of `workspaces.conf` and `MyProject.code-workspace` a file in the
`directory`.

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports a `default` line naming an unknown workspace or a `.code-workspace` file the
`directory` does not hold.

## Verification

```bash
Test-ConfigurationSchema --quiet
cat Unix/config/vscode-workspaces.local.conf
ls "$DOTFILES_ROOT/VSCode/Workspaces"
```

## Complete Example

`Unix/config/vscode-workspaces.local.conf`:

```conf
directory $DOTFILES_ROOT/VSCode/Workspaces
default MyProject MyProject
@Work default Client MyProject-Full
```

## Related

- [`Open-VSCodeWorkspace` in the Application module reference](../../modules/Application.md#open-vscodeworkspace)
- [Open-VSCode](Open-VSCode.md)
- [Application configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
