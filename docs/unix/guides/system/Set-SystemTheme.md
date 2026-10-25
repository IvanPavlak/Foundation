# Set-SystemTheme

Switches the macOS appearance to Dark or Light (or flips it), then runs the follow-up steps of
`theme.conf`, which set the matching wallpaper.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`theme.conf`](../../configuration.md#files) | `theme MACHINE Dark\|Light` | none | The theme `--auto` applies on machine type MACHINE; a machine type without a line keeps its appearance |
| [`theme.conf`](../../configuration.md#files) | `step NAME on\|off` | `step SetWallpaper on` | The follow-up steps; SetWallpaper runs [Set-Wallpaper](Set-Wallpaper.md) for the new theme. `--include` and `--skip` override it for one run (comma lists work), and any other step name stops it before anything changes |

The `prompt-theme` line of the same file is read by the shell rc, not by this command.

## Decisions

1. Which appearance should each machine type get from `Set-SystemTheme --auto`?
    - Options: one `theme MACHINE Dark|Light` line per machine type (`theme Work Dark`, `theme Laptop Light`); MACHINE compares case-insensitively and the last line for it wins.
    - Default: none, so `--auto` leaves the appearance as it is.
    - More detail: [`theme.conf`](../../configuration.md#files)
2. Should switching the theme also switch the wallpaper?
    - Options: `step SetWallpaper on` or `off`.
    - Default: `on` (also without a line).
    - More detail: [`theme.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/theme.local.conf`, created when missing. `theme.conf` has no sections: the overlay's
lines are added after the base lines and the last `theme` line for a machine type, and the last
`step` line for a step, wins, so an overlay line overrides the base. `-LINE` takes a base line
back and `@TYPE` limits a line to machine types.

## Steps Overview

1. Add the `theme` lines
2. Set the steps
3. Check the configuration

## Step 1: Add the `theme` lines

```conf
theme Work    Dark
theme Laptop  Light
```

## Step 2: Set the steps

Only when the wallpaper should stay as it is:

```conf
step SetWallpaper off
```

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `@TYPE` prefix that names a machine type `machines.conf` does not have; it does not
check the MACHINE field of a `theme` line.

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n '^theme\|^step' Unix/config/theme.local.conf
Set-Wallpaper --dry-run
```

`Set-Wallpaper --dry-run` shows the picture the SetWallpaper step would set for the current
appearance.

## Complete Example

`Unix/config/theme.local.conf`:

```conf
theme Work    Dark
theme Laptop  Light
step SetWallpaper on
```

## Related

- [`Set-SystemTheme` in the System module reference](../../modules/System.md#set-systemtheme)
- [Set-Wallpaper](Set-Wallpaper.md)
- [System configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
