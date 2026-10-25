# Logging Module Configuration Guides

The Logging module finds, pins and prunes the session and error logs every Foundation command
writes; see [the module reference](../../modules/Logging.md).

## Configurable Commands

| Command | Configuration files | Guide |
| ------- | ------------------- | ----- |
| `Clear-OldLogs` | `logging.conf` | [Clear-OldLogs](Clear-OldLogs.md) |
| `Get-LogPath` | `logging.conf` | [Get-LogPath](Get-LogPath.md) |
| `Invoke-LogMaintenance` | `logging.conf`, `backups.conf` | [Invoke-LogMaintenance](Invoke-LogMaintenance.md) |
| `Protect-Log` | `logging.conf` | [Protect-Log](Protect-Log.md) |

## Commands With No Configuration

None: every Logging command follows `logging.conf`.

## Related

- [All configuration guides](../README.md)
- [Configuration](../../configuration.md)
