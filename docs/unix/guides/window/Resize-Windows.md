# Resize-Windows

Scales matching windows by a percentage around their center, kept at least 100 points a side and
clamped to the work area, taking the default percentage from `window.conf`.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`window.conf`](../../configuration.md#files) | `resize-windows ROW PERCENT` | `resize-windows Default 70` | The percentage used without `--percent`; ROW is `SmallDisplay`, a machine type or `Default`. A fraction is rounded (33.5 gives 34, as on Windows); a missing row, a value that is not a number or one outside 10-500 gives 70 |
| [`machines.conf`](../../configuration.md#files) | `small-display-width POINTS` | `3000` | A primary display at most this wide (in points) uses the `SmallDisplay` row |
| [`machines.conf`](../../configuration.md#files) | `type NAME`, `host HOSTNAME TYPE`, `default TYPE` | `type Test`, `default Test` | The machine type, which picks the machine-type row when there is no `SmallDisplay` match and no `layout-override` or `small-display` redirects it |
| [`machines.conf`](../../configuration.md#files) | `layout-override TYPE TARGET`, `small-display TYPE` | none | The layout machine type, as for the layout sets: `layout-override` first, then `small-display` on a small primary display, else the machine type. Its row is the one tried after `SmallDisplay` |
| [`workspaces.conf`](../../configuration.md#workspacesconf), [`zones.conf`](../../configuration.md#zonesconf) | `layout-stable-ms ...`, `parking-workspace ...` and the zone sets | base values | Nothing for Resize-Windows: it loads the layout library only for the layout machine type, and the readers of these files in that library are not called |

## Decisions

1. By how much should Resize-Windows scale when no `--percent` is given?
    - Options: a `resize-windows Default PERCENT` line, a whole number from 10 to 500; 100 changes nothing, below shrinks, above enlarges.
    - Default: 70.
    - More detail: [`window.conf`](../../configuration.md#files)
2. Should a small display (a built-in laptop panel) use another percentage?
    - Options: a `resize-windows SmallDisplay PERCENT` line; it wins when the primary display is at most `small-display-width` points wide.
    - Default: no `SmallDisplay` row; the machine-type row or `Default` applies.
    - More detail: [`window.conf`](../../configuration.md#files)
3. Should one machine type use another percentage?
    - Options: a `resize-windows Work PERCENT` (or any `type` of `machines.conf`) line; it applies when no `SmallDisplay` row matched and the layout machine type is that type (`layout-override Work Laptop` makes a Work machine use the `Laptop` row; `small-display Laptop` does the same on a small primary display).
    - Default: only the `Default` row.
    - More detail: [`window.conf`](../../configuration.md#files)
4. Below which width does a display count as small?
    - Options: `small-display-width POINTS` in `machines.conf`.
    - Default: 3000, as on Windows.
    - More detail: [`machines.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/window.local.conf` and `Unix/config/machines.local.conf`, created when missing. Both
files have no sections: overlay lines are added after the base ones, and for one ROW the last
`resize-windows` line wins, so an overlay line with the same ROW replaces the base value.
`-LINE` takes a base line back; `@TYPE` limits a line to machine types.

## Steps Overview

1. Add the `resize-windows` rows
2. Check the small-display width
3. Check the configuration

## Step 1: Add the `resize-windows` rows

The rows are tried in the order `SmallDisplay` (only on a small primary display), the layout
machine type (`layout-override`, then `small-display`, then the machine type, as the layout sets
are chosen), `Default`; the first that exists applies. `--percent N` (10-500) always wins over
them.

```conf
resize-windows  Default       70
resize-windows  SmallDisplay  85
resize-windows  Work          60
```

At run time the windows come from the flags: `--process`, `--window-title`, `--current`, and
`--window-handle ID` for one window by the id `Get-WindowHandle` lists. A resized window is kept at
least 100 points wide and high. Each desktop holding a matching window is shown while its windows
are measured and resized (AeroSpace parks a hidden desktop's windows in a corner), and the
desktop focused before comes back at the end.

## Step 2: Check the small-display width

Only needed when the default of 3000 points does not separate your panels from your monitors.

```conf
small-display-width 2000
```

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It checks the machine types `machines.conf` names; it does not check `window.conf` rows, so read
them back (Verification).

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n '^resize-windows' Unix/config/window.conf Unix/config/window.local.conf
grep -n 'small-display-width' Unix/config/machines.conf Unix/config/machines.local.conf
```

For one ROW the last line printed is the one that applies.

## Complete Example

`Unix/config/window.local.conf`:

```conf
resize-windows  SmallDisplay  85
resize-windows  Work          60
```

`Unix/config/machines.local.conf`:

```conf
type Work
type Laptop
host My-Mac Work
default Laptop
small-display-width 2000
```

## Related

- [`Resize-Windows` in the Window module reference](../../modules/Window.md#resize-windows)
- [Reset-Windows](Reset-Windows.md)
- [Window configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
