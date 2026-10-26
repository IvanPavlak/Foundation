# List-Functions

Lists the Unix commands from their module pages in the Windows layout (module borders, name,
description, `Key => value` lines, a total border, the discrepancy report) and checks modules,
manifests and pages against each other, and that each page keeps its entries in alphabetical order.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`list-functions.conf`](../../configuration.md#files) | `border COLOR` | `Cyan` | The module, count and total borders (ListFunctionsColors.Border) |
| [`list-functions.conf`](../../configuration.md#files) | `discrepancy-error COLOR` | `BrightRed` | The discrepancy report |
| [`list-functions.conf`](../../configuration.md#files) | `discrepancy-success COLOR` | `BrightGreen` | The "No discrepancies" line |
| [`list-functions.conf`](../../configuration.md#files) | `function-name COLOR` | `Cyan` | Each command's name (ShowFunctionDetailsColors.FunctionName) |
| [`list-functions.conf`](../../configuration.md#files) | `description COLOR` | `White` | Each description |
| [`list-functions.conf`](../../configuration.md#files) | `parameters COLOR...` | `BrightCyan Cyan BrightBlue Blue` | The colours the `Key => value` lines cycle through |
| [`list-functions.conf`](../../configuration.md#files) | `exclude NAME` | none | A name the discrepancy check ignores in every direction (FunctionDiscrepancyExclusions) |

## Decisions

1. Should the listing use other colours?
    - Options: any name List-AvailableColors prints (Black, Red, Green, Yellow, Blue, Magenta, Cyan, White, each also as `Bright<Name>`) or a 256-colour number, per line kind.
    - Default: the Windows colours, mapped to ANSI (DarkCyan is `Cyan`, Gray is `White`, Cyan is `BrightCyan`).
    - More detail: [`list-functions.conf`](../../configuration.md#files)
2. Is there an executable or page entry the discrepancy check should not report?
    - Options: one `exclude NAME` line per name, for something that is deliberately neither a documented command nor a helper.
    - Default: none; every mismatch is reported.
    - More detail: [`list-functions.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/list-functions.local.conf`, created when missing. Its lines are added after the base
file's, and for each colour key the last line wins, so one line overrides one colour; `exclude`
lines add up. `@TYPE` limits a line to machine types.

## Steps Overview

1. Pick the colours
2. Add exclusions
3. Look at the result

## Step 1: Pick the colours

```conf
border        Magenta
parameters    BrightYellow Yellow
```

Run `List-AvailableColors` to see the names in this terminal's theme.

## Step 2: Add exclusions

```conf
exclude MyScratchScript
```

## Step 3: Look at the result

`List-Functions --category Helper` draws one module with its borders; `List-Functions
--list-discrepancies` shows whether an exclusion hides what it should.

## Verification

```bash
List-Functions --category Helper
List-Functions --list-discrepancies
cat Unix/config/list-functions.local.conf
```

## Complete Example

`Unix/config/list-functions.local.conf`:

```conf
border               Magenta
discrepancy-error    Red
discrepancy-success  Green
function-name        BrightWhite
description          White
parameters           BrightYellow Yellow BrightMagenta Magenta
exclude              MyScratchScript
```

## Related

- [`List-Functions` in the Helper module reference](../../modules/Helper.md#list-functions)
- [Helper configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
