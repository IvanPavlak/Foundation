# Move-Windows

Moves matching windows to a desktop (an AeroSpace workspace) and focuses it, set by flags rather
than configuration.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`window.conf`](../../configuration.md#files) | `center-terminal ...`, `resize-windows ...` | `Default` rows | Nothing for Move-Windows: the shared window library it loads holds the readers, which only Center-Terminal and Resize-Windows call |
| [`machines.conf`](../../configuration.md#files) | `small-display-width POINTS` | `3000` | Nothing for Move-Windows, for the same reason |

Move-Windows takes the desktop and the windows from its flags only; the files are listed because
the window library it shares with Center-Terminal and Resize-Windows reads them.

## Decisions

1. Which desktop should the windows go to?
    - Options: `--desktop N` (or `--virtual-desktop N`, or a bare number), a whole number from 1 to 100; `--current` for the focused one. A desktop that does not exist yet is created on first use.
    - Default: desktop 1.
    - More detail: [`Move-Windows` in the Window module reference](../../modules/Window.md#move-windows)
2. Which windows should move?
    - Options: `--process PATTERN` (or `--process-name`; an `apps.conf` token, a role such as `Browser`, or an app name) and `--window-title PATTERN` (exact, `*wildcard*` or regex, case-insensitive); given both, a window matching either moves, as on Windows.
    - Default: every window AeroSpace manages.
    - More detail: [`Move-Windows` in the Window module reference](../../modules/Window.md#move-windows)

## Where to Put Values

There is nothing to put anywhere for Move-Windows. The `window.conf` and `machines.conf` lines
belong to [Center-Terminal](Center-Terminal.md) and [Resize-Windows](Resize-Windows.md).

## Steps Overview

1. Choose the flags
2. Check the configuration

## Step 1: Choose the flags

Move-Windows is pure AeroSpace and needs no Accessibility permission. `--monitor` is accepted and
ignored with a warning: only one display is managed on macOS yet. A window AeroSpace refuses to
move is counted: the run then ends with `N window(s) could not be moved to desktop D` and exit
status 1, after moving the others and focusing the desktop.

```bash
Move-Windows --desktop 3 --process Code
Move-Windows --current --window-title '*MyProject*'
```

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

Nothing it checks affects Move-Windows; run it when you changed `machines.conf`.

## Verification

```bash
Get-WindowHandle --process-name Code
aerospace list-workspaces --all
```

The first lists the windows an app pattern matches and the desktop each is on (Move-Windows
selects windows by the same rules), the second the desktops that exist; neither changes
anything.

## Complete Example

Move-Windows has no configuration of its own; a typical call:

```bash
Move-Windows --desktop 2 --process Code --window-title '*MyProject*'
```

## Related

- [`Move-Windows` in the Window module reference](../../modules/Window.md#move-windows)
- [Reset-Windows](Reset-Windows.md)
- [Window configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
