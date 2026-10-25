# Clear-OldLogs

Applies the log retention of `logging.conf` now: prunes old session logs from the log folder and
trims an oversized error log to its newest half of `max-error-file-size-mb`, never touching
`Pinned`; `--dry-run` (or `--what-if`) lists what would go. This page also covers the lines of
`logging.conf` every command reads (the level, the colours, the folder and the error log's name).

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`logging.conf`](../../configuration.md#files) | `max-age-days N` | `7` | Session logs older than N days are removed; `0` turns the limit off |
| [`logging.conf`](../../configuration.md#files) | `max-session-files N` | `20` | At most N session logs are kept, the oldest go first; `0` turns the limit off |
| [`logging.conf`](../../configuration.md#files) | `max-total-size-mb N` | `50` | The oldest session logs go while all of them together exceed N MB; `0` turns the limit off |
| [`logging.conf`](../../configuration.md#files) | `max-error-file-size-mb N` | `5` | An error log larger than N MB is cut down to its newest half of that size; `0` turns the limit off |
| [`logging.conf`](../../configuration.md#files) | `logging on\|off` | `on` | Whether commands write session logs at all; Clear-OldLogs prunes either way |
| [`logging.conf`](../../configuration.md#files) | `directory PATH` | empty (`Unix/logs`) | The log folder every command writes into and Clear-OldLogs prunes; `~` is the home folder, a relative path is under the repository |
| [`logging.conf`](../../configuration.md#files) | `error-file NAME` | `Errors.log` | The error log's file name in that folder |
| [`logging.conf`](../../configuration.md#files) | `level normal\|quiet\|verbose` | `normal` | The console level every command starts with: `quiet` prints only warnings and errors, `verbose` adds the debug lines; `FOUNDATION_LOG_LEVEL` and `-v` beat it |
| [`logging.conf`](../../configuration.md#files) | `color STYLE COLOR` | none (title cyan, step plain, success green, warning yellow, error red, debug grey, info blue) | The console colour of one STYLE (`title`, `step`, `success`, `warning`, `error`, `debug`, `info`): a List-AvailableColors name, `plain`, or an SGR code |

## Decisions

1. How long should session logs be kept?
    - Options: `max-age-days` with a number of days, or `0` for no age limit.
    - Default: 7 days.
    - More detail: [`logging.conf`](../../configuration.md#files)
2. How many session logs should be kept at most?
    - Options: `max-session-files` with a count, or `0` for no count limit.
    - Default: 20.
    - More detail: [`logging.conf`](../../configuration.md#files)
3. How much disk space may the session logs take together?
    - Options: `max-total-size-mb` with a size in MB, or `0` for no size limit.
    - Default: 50 MB.
    - More detail: [`logging.conf`](../../configuration.md#files)
4. How large may the error log grow before it is trimmed?
    - Options: `max-error-file-size-mb` with a size in MB, or `0` to let it grow.
    - Default: 5 MB.
    - More detail: [`logging.conf`](../../configuration.md#files)
5. Should commands write log files at all?
    - Options: `logging on` or `logging off`; `FOUNDATION_LOGGING=off` turns it off for one run.
    - Default: `on`.
    - More detail: [`logging.conf`](../../configuration.md#files)
6. Where should the logs live, and what is the error log called?
    - Options: `directory PATH` (empty for `Unix/logs`) and `error-file NAME`; `FOUNDATION_LOG_DIR` moves the folder for one run.
    - Default: `Unix/logs` and `Errors.log`.
    - More detail: [`logging.conf`](../../configuration.md#files)
7. How much should commands print on the console?
    - Options: `level normal`, `level quiet` (only warnings and errors) or `level verbose` (debug lines too); `FOUNDATION_LOG_LEVEL` overrides it for a shell or one command, `-v` for one command.
    - Default: `normal`.
    - More detail: [`logging.conf`](../../configuration.md#files)
8. Should any log style have another colour?
    - Options: a `color STYLE COLOR` line per style to change, COLOR from `List-AvailableColors`, `plain`, or an SGR code.
    - Default: no line, the colours above.
    - More detail: [`logging.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/logging.local.conf`, created when missing. Its lines (the file has no sections)
override the base value of the same key, the last line of a key winning. A line may start with
`@TYPE` to apply on one machine type only (`@Laptop max-total-size-mb 20`), and `-LINE` takes a
base line back (`-max-age-days 7`; the key then falls back to the built-in value, the one the base
file ships). The same limits also run in the background whenever a command starts a session, so
Clear-OldLogs is only needed to apply them right away; the flags `--max-age-days`,
`--max-session-files`, `--max-total-size-mb` and `--max-error-file-size-mb` override a limit for
one run (`Clear-OldLogs --max-session-files 5`).

## Steps Overview

1. Set the limits
2. Set the console level and colours
3. Check the configuration

## Step 1: Set the limits

Only the keys you change:

```conf
max-age-days        14
max-session-files   50
```

A log you want to keep beyond the limits goes into `Unix/logs/Pinned`
([Protect-Log](Protect-Log.md)).

## Step 2: Set the console level and colours

Only what differs from the defaults, for every command on this machine:

```conf
level           quiet
color title     BrightCyan
color success   38;5;114
```

`FOUNDATION_LOG_LEVEL=verbose` (exported, or before one command) still wins over the line, and
`-v` makes one command verbose. Run `List-AvailableColors` for the names.

## Step 3: Check the configuration

```bash
Clear-OldLogs --dry-run
```

It lists every log the limits would remove, each once, and, when the error log is past
`max-error-file-size-mb`, the size it would be trimmed to (half of that limit), and changes
nothing.

## Verification

```bash
Clear-OldLogs --dry-run
Get-LogPath --directory
cat Unix/config/logging.local.conf
ls "$(Get-LogPath --directory)"
```

## Complete Example

`Unix/config/logging.local.conf`:

```conf
logging                  on
level                    normal
directory                ~/Logs/Foundation
error-file               Errors.log
color title              BrightCyan
max-age-days             14
max-session-files        50
max-total-size-mb        100
max-error-file-size-mb   10
```

## Related

- [`Clear-OldLogs` in the Logging module reference](../../modules/Logging.md#clear-oldlogs)
- [Invoke-LogMaintenance](Invoke-LogMaintenance.md), the periodic sweep that also prunes backups and test results
- [Logging configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
