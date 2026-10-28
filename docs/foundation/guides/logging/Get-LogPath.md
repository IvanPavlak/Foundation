# Get-LogPath

Prints the path of the newest session log (of any command, or of one), of the error log, of every
session log, or of the logs folder; only the path goes to stdout.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`logging.conf`](../../configuration.md#files) | `directory PATH` | empty (`Unix/logs`) | The folder it searches and `--directory` prints |
| [`logging.conf`](../../configuration.md#files) | `error-file NAME` | `Errors.log` | The file `--errors` prints |

## Decisions

1. Where do the logs live, and what is the error log called?
    - Options: set them once for every command, as [Clear-OldLogs](Clear-OldLogs.md) describes; Get-LogPath only follows them.
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

It prints the folder every command now writes into.

## Verification

```bash
Get-LogPath
Get-LogPath w
Get-LogPath Open-Workspace --all
Get-LogPath --errors
Get-LogPath --directory
less "$(Get-LogPath w)"
```

## Complete Example

`Unix/config/logging.local.conf`:

```conf
directory    ~/Logs/Foundation
error-file   Errors.log
```

## Related

- [`Get-LogPath` in the Logging module reference](../../modules/Logging.md#get-logpath)
- [Logging configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
