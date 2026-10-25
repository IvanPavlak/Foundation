# Protect-Log

Pins a copy of a log into the `Pinned` folder of the log folder, which retention never prunes: the
newest session log, the newest of one command, a file you name, or a snapshot of the error log.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`logging.conf`](../../configuration.md#files) | `directory PATH` | empty (`Unix/logs`) | The folder whose session logs it pins and whose `Pinned` folder it copies into |
| [`logging.conf`](../../configuration.md#files) | `error-file NAME` | `Errors.log` | The file `--error-log` snapshots (`Errors_<timestamp>.log` for the default name) |

## Decisions

1. Where do the logs live, and what is the error log called?
    - Options: set them once for every command, as [Clear-OldLogs](Clear-OldLogs.md) describes; Protect-Log only follows them.
    - Default: `Unix/logs` and `Errors.log`.
    - More detail: [`logging.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/logging.local.conf`, created when missing; see [Clear-OldLogs](Clear-OldLogs.md)
for how its lines combine with the base. `FOUNDATION_LOG_DIR` beats `directory` for one run.

## Steps Overview

1. Set the folder and the error log's name
2. Check the configuration

## Step 1: Set the folder and the error log's name

```conf
directory    ~/Logs/Foundation
error-file   Errors.log
```

## Step 2: Check the configuration

```bash
Get-LogPath --directory
```

`Pinned` is a folder inside the folder it prints.

## Verification

```bash
Get-LogPath --directory
ls "$(Get-LogPath --directory)/Pinned"
```

Pinning itself copies a file (`Protect-Log`, `Protect-Log w`, `Protect-Log --error-log`, or a path
such as `Protect-Log Unix/logs/Session_2026-01-01_09-00-00_Open-Workspace.log`).

## Complete Example

`Unix/config/logging.local.conf`:

```conf
directory    ~/Logs/Foundation
error-file   Errors.log
```

## Related

- [`Protect-Log` in the Logging module reference](../../modules/Logging.md#protect-log)
- [Logging configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
