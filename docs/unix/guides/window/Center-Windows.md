# Center-Windows

Floats matching windows out of AeroSpace's tiling and centers them on the primary display at a
share of its work area, set by flags rather than configuration.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`window.conf`](../../configuration.md#files) | `center-terminal ROW WIDTH HEIGHT MIN-W% MAX-W% MIN-H% MAX-H%` | `center-terminal Default 1376 700 25 72 35 75` | Nothing when Center-Windows is run directly; the size Center-Terminal asks it to center WezTerm at |
| [`machines.conf`](../../configuration.md#files) | `small-display-width POINTS` | `3000` | Nothing when Center-Windows is run directly; which `center-terminal` row Center-Terminal uses |

Center-Windows loads the shared window library, which can read the display-aware rows above,
but Center-Windows itself takes its size only from `--width-percent` and `--height-percent`.
The rows reach it only through [Center-Terminal](Center-Terminal.md), which turns them into the
percentages it passes here.

## Decisions

1. Should the centered size come from configuration?
    - Options: no for Center-Windows itself - pass `--width-percent N` and `--height-percent N` (whole numbers from 10 to 100, as on Windows; anything else is an error before a window is touched); for the terminal, set the `center-terminal` rows and run Center-Terminal instead.
    - Default: 40 % of the work area's width by 50 % of its height.
    - More detail: [Center-Terminal](Center-Terminal.md)
2. Which windows should be centered?
    - Options: `--process PATTERN` (or `--process-name`; an `apps.conf` token, a role such as `Browser`, or an app name), `--window-title PATTERN` (exact, `*wildcard*` or regex, case-insensitive; given both, a window matching either is centered, as on Windows), `--current` for the focused desktop only.
    - Default: every window AeroSpace manages, on every desktop.
    - More detail: [`Center-Windows` in the Window module reference](../../modules/Window.md#center-windows)

## Where to Put Values

There is nothing to put anywhere for Center-Windows itself. The `center-terminal` rows used
through Center-Terminal go in `Unix/config/window.local.conf` and the display width in
`Unix/config/machines.local.conf`, both created when missing; see
[Center-Terminal](Center-Terminal.md#where-to-put-values).

## Steps Overview

1. Choose the flags
2. Check the configuration

## Step 1: Choose the flags

Centering needs the Accessibility permission of the terminal (System Settings > Privacy &
Security > Accessibility). Every matching window is centered by its own window id, so two windows
of one app with the same title are both centered. Each desktop holding a matching window is
shown while its windows are centered (AeroSpace parks a hidden desktop's windows in a corner and
would put them back where it remembers), and the desktop focused before comes back at the end.
`Reset-Windows --current` tiles the windows again. The Windows flags
`--on-primary` and `--monitor M` are accepted and ignored: windows are always centered on the
primary display, the only one managed on macOS yet.

```bash
Center-Windows --process Code --width-percent 60 --height-percent 70
Center-Windows --window-title '*MyProject*' --current
```

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

Only relevant when you changed the `machines.conf` lines Center-Terminal reads.

## Verification

```bash
Get-WindowHandle --process-name Code
Get-WindowHandle --window-title '*MyProject*'
```

Each lists the windows a pattern matches, without changing anything. Center-Windows selects
windows by the same rules, so `Get-WindowHandle` given the same `--process-name` and
`--window-title` lists exactly the windows it would center (on every desktop; `--current` keeps
the focused one's).

## Complete Example

Center-Windows has no configuration of its own; the overlay lines it is driven with through
Center-Terminal, in `Unix/config/window.local.conf`:

```conf
center-terminal  SmallDisplay  1100 640  30 80  40 85
```

## Related

- [`Center-Windows` in the Window module reference](../../modules/Window.md#center-windows)
- [Center-Terminal](Center-Terminal.md)
- [Window configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
