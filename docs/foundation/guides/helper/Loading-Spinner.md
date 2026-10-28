# Loading-Spinner

Runs a command while a spinner from `spinners.conf` shows that it is still working, the same
spinner every long wait (Docker start and stop, the layout's wait for windows) draws.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`spinners.conf`](../../configuration.md#files) | `default STYLE` | `Dots` | The style every wait and `Loading-Spinner` without `--style` uses |
| [`spinners.conf`](../../configuration.md#files) | `STYLE DELAY-MS FRAME...` | the 19 styles of WinuX's base (`BrailleBlocks`, `Dots`, `Line`, `Arrows`, `Box`, `Circle`, `Moon`, `Clock`, `Star`, `Dot`, `GrowingDots`, `BlockFill`, `Pulse`, `Binary`, `Triangle`, `BarBlocks`, `SquareCorners`, `Hamburger`, `Arc`) with its frames and delays (50 ms, `Binary` 100), plus `Bounce` | One style: milliseconds per frame, then its frames; `--preview` animates each |

## Decisions

1. Which spinner style should waits show?
    - Options: the name of any style line (case-insensitive); `--style` picks another for one call.
    - Default: `Dots`; an unknown name, or a missing file, falls back to the `- \ | /` frames at 120 ms.
    - More detail: [`spinners.conf`](../../configuration.md#files)
2. Do you want a style of your own?
    - Options: a line `NAME DELAY-MS FRAME...`, the frames separated by spaces; any delay in milliseconds (1500 is a frame every 1.5 s).
    - Default: the five base styles.
    - More detail: [`spinners.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/spinners.local.conf`, created when missing. The file has no sections: its lines are
added after the base ones. The last line of a name wins, for `default` and for a style alike, so
an overlay line with a base style's name replaces that style (no `-LINE` needed). `-LINE` (the
exact base line) still takes a base line back. An `@TYPE` prefix limits a line to machine types.

## Steps Overview

1. Add a style
2. Choose the default
3. Check the configuration

## Step 1: Add a style

```conf
Pulse    150  · • ● •
```

## Step 2: Choose the default

```conf
default  Pulse
```

## Step 3: Check the configuration

```bash
Loading-Spinner --preview
```

It animates every style for two seconds, each name once (in the form its last line gives), the
new one included. `Test-ConfigurationSchema` does
not check this file.

## Verification

```bash
cat Unix/config/spinners.local.conf
Loading-Spinner --preview
Loading-Spinner --label "Waiting..." -- sleep 3
```

## Complete Example

`Unix/config/spinners.local.conf`:

```conf
default  Pulse
@Laptop default Line

Pulse    150  · • ● •
Arc      60   ◜ ◠ ◝ ◞ ◡ ◟
```

## Related

- [`Loading-Spinner` in the Helper module reference](../../modules/Helper.md#loading-spinner)
- [Helper configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
