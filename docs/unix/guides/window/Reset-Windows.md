# Reset-Windows

Retiles desktops into a clean, balanced state in place: floating windows go back into the tiling,
the tree is flattened into one row and the tiles are balanced.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`window.conf`](../../configuration.md#files) | `center-terminal ...`, `resize-windows ...` | `Default` rows | Nothing for Reset-Windows: the shared window library it loads holds the readers, which only Center-Terminal and Resize-Windows call |
| [`machines.conf`](../../configuration.md#files) | `small-display-width POINTS` | `3000` | Nothing for Reset-Windows, for the same reason |

Reset-Windows is driven by its flags only; the files are listed because the window library it
shares with Center-Terminal and Resize-Windows reads them.

## Decisions

1. Which desktops should be reset?
    - Options: `--desktop N` (or `--virtual-desktop N`, or a bare number) for one desktop, `--current` for the focused one.
    - Default: every desktop that has windows; windows stay on their desktops.
    - More detail: [`Reset-Windows` in the Window module reference](../../modules/Window.md#reset-windows)
2. Should every window be gathered onto one desktop first, as on Windows?
    - Options: `--gather N` moves every window to desktop N (through Move-Windows) and then resets only that desktop.
    - Default: no gathering.
    - More detail: [Move-Windows](Move-Windows.md)

## Where to Put Values

There is nothing to put anywhere for Reset-Windows. The `window.conf` and `machines.conf` lines
belong to [Center-Terminal](Center-Terminal.md) and [Resize-Windows](Resize-Windows.md).

## Steps Overview

1. Choose the flags
2. Check the configuration

## Step 1: Choose the flags

`--center` and `--monitor` are accepted and ignored with a warning: they have no AeroSpace
counterpart. `w <Workspace>` applies a layout again afterwards.

```bash
Reset-Windows
Reset-Windows --current
Reset-Windows --gather 1
```

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

Nothing it checks affects Reset-Windows; run it when you changed `machines.conf`.

## Verification

```bash
Get-WindowHandle
aerospace list-workspaces --all
```

They list the windows with their desktops and the desktops that exist, without changing
anything.

## Complete Example

Reset-Windows has no configuration of its own; a typical call after Center-Windows or
Resize-Windows floated windows on the focused desktop:

```bash
Reset-Windows --current
```

## Related

- [`Reset-Windows` in the Window module reference](../../modules/Window.md#reset-windows)
- [Move-Windows](Move-Windows.md)
- [Window configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
