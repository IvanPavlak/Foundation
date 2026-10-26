# Invoke-Onefetch

Shows the onefetch repository panel of the terminal greeting when the folder is inside a git
repository, restyled with the colors and separator of `greeting.conf`.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`greeting.conf`](../../configuration.md#files) | `onefetch on\|off` | `off` | Whether the panel is drawn; only `on` shows it, so a missing line means off, as WinuX's base `Onefetch.Enabled` |
| [`greeting.conf`](../../configuration.md#files) | `onefetch-auto-fit on\|off` | `on` | Whether `--measure` reports the panel's height, so fastfetch leaves room for it; `off` reports 0 |
| [`greeting.conf`](../../configuration.md#files) | `onefetch-arguments ARGS...` | none | The arguments passed to onefetch |
| [`greeting.conf`](../../configuration.md#files) | `onefetch-separator "TEXT"` | none | Replaces the colon after each field name; quoted so spaces survive. Without a line the colon stays |
| [`greeting.conf`](../../configuration.md#files) | `onefetch-color INDEX SGR` | none | Maps an ANSI index onefetch was given (0-15) onto an SGR code (`38;2;R;G;B`) |

`onefetch-in-project-terminals` is read by Open-ProjectTerminals, and the other `greeting.conf`
lines by [Invoke-Clear](Invoke-Clear.md) and [Invoke-Fastfetch](Invoke-Fastfetch.md).

## Decisions

1. Should the greeting show the repository panel inside a git repository?
    - Options: `onefetch on` or `onefetch off`.
    - Default: `off` in the base file, as WinuX's base; a file with no `onefetch` line keeps it off.
    - More detail: [`greeting.conf`](../../configuration.md#files)
2. Should fastfetch count the panel's height when it fits itself to the window?
    - Options: `onefetch-auto-fit on` or `off`.
    - Default: `on`.
    - More detail: [`greeting.conf`](../../configuration.md#files)
3. How should the panel look?
    - Options: `onefetch-arguments` with any onefetch arguments (`--text-colors`, `--nerd-fonts`, `--no-bold`, ...); `onefetch-separator "TEXT"`; one `onefetch-color INDEX SGR` line per index to recolor, INDEX 0-15 (onefetch itself takes only those).
    - Default: no arguments, the colon and onefetch's own colors. `Invoke-Onefetch --arguments ARGS...` (or `onefetch ARGS...` at the prompt) replaces `onefetch-arguments` for one call. The overlay's `onefetch-arguments` and `onefetch-separator` lines win; its `onefetch-color` lines are added to the base ones, and for an INDEX mapped twice the last line wins, so an overlay line changes a base color.
    - More detail: [`greeting.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/greeting.local.conf`, created when missing. `greeting.conf` has no sections: the
overlay's lines are added after the base lines and the last line wins: for `onefetch`,
`onefetch-auto-fit`, `onefetch-arguments` and `onefetch-separator`, and for `onefetch-color` per
index. Keys are case-insensitive. `-LINE` takes a base line back (`-onefetch-color 9 38;2;255;0;0`),
and `@TYPE` limits a line to machine types.

## Steps Overview

1. Turn the panel on or off
2. Style the panel
3. Check the configuration

## Step 1: Turn the panel on or off

```conf
onefetch           on
onefetch-auto-fit  on
```

## Step 2: Style the panel

```conf
onefetch-arguments  --text-colors 12 9 9 12 9 15 --nerd-fonts --no-bold
onefetch-separator  " : "
onefetch-color      14  38;2;0;128;255
```

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `@TYPE` prefix that names a machine type `machines.conf` does not have.

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n 'onefetch' Unix/config/greeting.local.conf
Invoke-Onefetch --measure
Invoke-Onefetch
```

Run inside a repository; `--measure` prints the panel's height (0 when nothing would be drawn).
A bare `onefetch` typed at the prompt draws the same restyled panel, even with `onefetch off`.

## Complete Example

`Unix/config/greeting.local.conf`:

```conf
onefetch            on
onefetch-auto-fit   on
onefetch-arguments  --text-colors 12 9 9 12 9 15 --nerd-fonts --no-bold
onefetch-separator  " : "
onefetch-color      9   38;2;220;20;60
@Laptop onefetch off
```

## Related

- [`Invoke-Onefetch` in the System module reference](../../modules/System.md#invoke-onefetch)
- [System configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
