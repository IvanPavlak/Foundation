# Invoke-Fastfetch

Draws the fastfetch system panel of the terminal greeting, shrinking the WezTerm font or dropping
the logo until it fits the window.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`greeting.conf`](../../configuration.md#files) | `fastfetch on\|off` | `on` | Whether the panel is drawn at all; `off` makes the command silent |
| [`greeting.conf`](../../configuration.md#files) | `fastfetch-auto-fit on\|off` | `on` | Measure the panel and fit it to the window; `off` draws it once, unmeasured, as `--no-resize` does |
| [`greeting.conf`](../../configuration.md#files) | `fastfetch-max-shrink-steps N` | `10` | WezTerm font steps allowed below the default, 0-50 |
| [`greeting.conf`](../../configuration.md#files) | `fastfetch-reflow-timeout-ms N` | `10` | How long to wait for the window to reflow after a font step, 1-10000 ms |
| [`greeting.conf`](../../configuration.md#files) | `fastfetch-prompt-reserve N` | `1` | Rows kept free below the panels for the next prompt, 0-20 |
| [`greeting.conf`](../../configuration.md#files) | `image-logo PATH [WxH]` | none, so the text logo | The image drawn instead of the text logo of `FastFetch/Unix/config_<Type>.jsonc` in WezTerm, Ghostty and kitty; WxH in cells, default `30x14` |

The other `greeting.conf` lines belong to [Invoke-Clear](Invoke-Clear.md) and
[Invoke-Onefetch](Invoke-Onefetch.md).

## Decisions

1. Should the greeting show the fastfetch panel?
    - Options: `fastfetch on` or `fastfetch off` (only the exact value `off` turns it off).
    - Default: `on`; without fastfetch installed the command is silent anyway.
    - More detail: [`greeting.conf`](../../configuration.md#files)
2. Should the panel be fitted to the window?
    - Options: `fastfetch-auto-fit on` (measure; in WezTerm reset the font, then shrink it step by step; elsewhere drop the logo when it overflows) or `off` (draw once, leave the font alone).
    - Default: `on`.
    - More detail: [`greeting.conf`](../../configuration.md#files)
3. How far may the fit go, and how much room should it leave?
    - Options: `fastfetch-max-shrink-steps` 0-50, `fastfetch-reflow-timeout-ms` 1-10000, `fastfetch-prompt-reserve` 0-20, whole numbers. A value outside its range, or not a number, is warned about at every greeting and falls back to the default. `--max-shrink-steps`, `--reflow-timeout-milliseconds` and `--prompt-reserve` override a value for one call (`c --max-shrink-steps 0` shows whether the panels fit at the default font).
    - Default: 10 steps, 10 ms, 1 row.
    - More detail: [`greeting.conf`](../../configuration.md#files)
4. Should a machine type show an image instead of the text logo?
    - Options: `@TYPE image-logo PATH [WxH]`; PATH takes `~` and `$VARIABLES`, a relative PATH is under the repository. The image shows only in WezTerm, Ghostty and kitty, and only when the file exists. The last line for this machine type wins.
    - Default: none, so every machine type keeps the text logo of its fastfetch config.
    - More detail: [`greeting.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/greeting.local.conf`, created when missing. `greeting.conf` has no sections: the
overlay's lines are added after the base lines and the last line of each key for this machine
type wins, so an overlay line overrides the base. `@TYPE` limits a line to machine types, which
is how each machine type gets its own `image-logo`.

## Steps Overview

1. Set the fit
2. Add the image logos
3. Check the configuration

## Step 1: Set the fit

Change only what differs from the base values.

```conf
fastfetch-max-shrink-steps   6
fastfetch-prompt-reserve     2
```

## Step 2: Add the image logos

```conf
@Work   image-logo Images/MyLogo.png
@Laptop image-logo ~/Pictures/MyLogo.png 24x12
```

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `@TYPE` prefix that names a machine type `machines.conf` does not have; a missing
image file shows only as the text logo.

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n 'fastfetch\|image-logo' Unix/config/greeting.local.conf
Invoke-Fastfetch --no-resize
```

`--no-resize` draws the panel without touching the font; a bare `fastfetch` typed at the prompt
draws the same panel.

## Complete Example

`Unix/config/greeting.local.conf`:

```conf
fastfetch                    on
fastfetch-auto-fit           on
fastfetch-max-shrink-steps   6
fastfetch-reflow-timeout-ms  20
fastfetch-prompt-reserve     2
@Work   image-logo Images/MyLogo.png
@Laptop image-logo ~/Pictures/MyLogo.png 24x12
```

## Related

- [`Invoke-Fastfetch` in the System module reference](../../modules/System.md#invoke-fastfetch)
- [System configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
