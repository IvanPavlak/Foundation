# Center-Terminal

Floats the WezTerm window and centers it on the primary display at a size that looks the same on
a laptop panel and a large monitor, the macOS twin of the Windows Center-Terminal.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`window.conf`](../../configuration.md#files) | `center-terminal ROW WIDTH HEIGHT MIN-W% MAX-W% MIN-H% MAX-H%` | `center-terminal Default 1376 700 25 72 35 75` | The terminal's target size in points and the percent bounds its share of the work area is clamped to (and then into 10-100, the range of Center-Windows). ROW is `SmallDisplay`, a machine type or `Default` |
| [`machines.conf`](../../configuration.md#files) | `small-display-width POINTS` | `3000` | A primary display at most this wide (in points) uses the `SmallDisplay` row |
| [`machines.conf`](../../configuration.md#files) | `type NAME`, `host HOSTNAME TYPE`, `default TYPE` | `type Test`, `default Test` | The machine type, which picks the machine-type row when there is no `SmallDisplay` match and no `layout-override` or `small-display` redirects it |
| [`machines.conf`](../../configuration.md#files) | `layout-override TYPE TARGET`, `small-display TYPE` | none | The layout machine type, as for the layout sets: `layout-override` first, then `small-display` on a small primary display, else the machine type. Its row is the one tried after `SmallDisplay` |
| [`workspaces.conf`](../../configuration.md#workspacesconf), [`zones.conf`](../../configuration.md#zonesconf) | `layout-stable-ms ...`, `parking-workspace ...` and the zone sets | base values | Nothing for Center-Terminal: it loads the layout library only for the layout machine type, and the readers of these files in that library are not called |

## Decisions

1. How large should the centered terminal be?
    - Options: a `center-terminal Default WIDTH HEIGHT MIN-W% MAX-W% MIN-H% MAX-H%` line; WIDTH and HEIGHT in points, the four bounds in whole percent of the primary display's work area.
    - Default: 1376 x 700 points, clamped to 25-72 % of the width and 35-75 % of the height (also used when `window.conf` has no matching row).
    - More detail: [`window.conf`](../../configuration.md#files)
2. Should a small display (a built-in laptop panel) get its own size?
    - Options: a `center-terminal SmallDisplay ...` line; it wins over every other row when the primary display is at most `small-display-width` points wide.
    - Default: no `SmallDisplay` row; the machine-type row or `Default` applies.
    - More detail: [`window.conf`](../../configuration.md#files)
3. Should one machine type use a different size?
    - Options: a `center-terminal Work ...` (or `Laptop`, any `type` of `machines.conf`) line; it applies when no `SmallDisplay` row matched and the layout machine type is that type (`layout-override Work Laptop` makes a Work machine use the `Laptop` row; `small-display Laptop` does the same on a small primary display).
    - Default: only the `Default` row.
    - More detail: [`window.conf`](../../configuration.md#files)
4. Below which width does a display count as small?
    - Options: `small-display-width POINTS` in `machines.conf`, a whole number of points.
    - Default: 3000, as on Windows.
    - More detail: [`machines.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/window.local.conf` and `Unix/config/machines.local.conf`, created when missing. Both
files have no sections: overlay lines are added after the base ones, and for one ROW the last
`center-terminal` line wins, so an overlay line with the same ROW replaces the base value.
`-LINE` takes a base line back; `@TYPE` limits a line to machine types.

## Steps Overview

1. Add the `center-terminal` rows
2. Check the small-display width
3. Check the configuration

## Step 1: Add the `center-terminal` rows

The rows are tried in the order `SmallDisplay` (only on a small primary display), the layout
machine type (`layout-override`, then `small-display`, then the machine type, as the layout sets
are chosen), `Default`. The target size becomes shares of the live work area, clamped to the
bounds and then into 10-100, then Center-Windows floats and centers WezTerm at those shares. When
the work area cannot be read the terminal is handed Center-Windows' own 40 x 50.

```conf
center-terminal  Default       1376 700  25 72  35 75
center-terminal  SmallDisplay  1100 640  30 80  40 85
center-terminal  Work          1600 800  25 60  35 70
```

## Step 2: Check the small-display width

Only needed when the default of 3000 points does not separate your panels from your monitors.

```conf
small-display-width 2000
```

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It checks that every machine type `machines.conf` names is a `type` line; it does not check
`window.conf` rows, so read them back (Verification).

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n '^center-terminal' Unix/config/window.conf Unix/config/window.local.conf
grep -n 'small-display-width' Unix/config/machines.conf Unix/config/machines.local.conf
```

For one ROW the last line printed is the one that applies.

## Complete Example

`Unix/config/window.local.conf`:

```conf
center-terminal  SmallDisplay  1100 640  30 80  40 85
center-terminal  Work          1600 800  25 60  35 70
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

- [`Center-Terminal` in the Window module reference](../../modules/Window.md#center-terminal)
- [Center-Windows](Center-Windows.md)
- [Window configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
