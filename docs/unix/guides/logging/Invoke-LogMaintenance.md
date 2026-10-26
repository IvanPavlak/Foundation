# Invoke-LogMaintenance

The periodic sweep, at most once per interval: the log retention of Clear-OldLogs, the backup
retention of Clear-OldBackups and the test-results retention of Run-Tests, silently; every new
session runs it in the background when it is due.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`logging.conf`](../../configuration.md#files) | `maintenance on\|off` | `on` | Whether a new session runs the sweep when it is due; `--force` runs it either way |
| [`logging.conf`](../../configuration.md#files) | `maintenance-interval-hours N` | `24` | The least time between two sweeps (the stamp `.last-maintenance` in the log folder); `0` sweeps on every session |
| [`logging.conf`](../../configuration.md#files) | the retention lines | see [Clear-OldLogs](Clear-OldLogs.md) | What the log part of the sweep removes |
| [`backups.conf`](../../configuration.md#files) | `max-age-days`, `max-backups-per-key`, `max-total-size-mb` | see [Clear-OldBackups](../helper/Clear-OldBackups.md) | What the backup part of the sweep removes |

## Decisions

1. Should the sweep run on its own?
    - Options: `maintenance on`, or `maintenance off` to prune only by hand (Clear-OldLogs, Clear-OldBackups, `Invoke-LogMaintenance --force`).
    - Default: `on`.
    - More detail: [`logging.conf`](../../configuration.md#files)
2. How often may it run?
    - Options: `maintenance-interval-hours N`, a whole number of hours; `0` runs it on every new session.
    - Default: 24 hours.
    - More detail: [`logging.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/logging.local.conf`, created when missing. Its lines override the base value of the
same key, the last line of a key winning; `@TYPE` limits a line to one machine type
(`@Laptop maintenance-interval-hours 72`). The test-results rules (the ten newest run logs, then
a day's grace) are fixed, as on Windows.

## Steps Overview

1. Set the switch and the interval
2. Check the configuration

## Step 1: Set the switch and the interval

```conf
maintenance                  on
maintenance-interval-hours   12
```

## Step 2: Check the configuration

```bash
Clear-OldLogs --dry-run
Clear-OldBackups --dry-run
```

They list what the log and backup parts of the next sweep would remove.

## Verification

```bash
cat Unix/config/logging.local.conf
ls -l "$(Get-LogPath --directory)/.last-maintenance"
```

The stamp's time is the last sweep.

## Complete Example

`Unix/config/logging.local.conf`:

```conf
maintenance                  on
maintenance-interval-hours   12
```

## Related

- [`Invoke-LogMaintenance` in the Logging module reference](../../modules/Logging.md#invoke-logmaintenance)
- [Logging configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
