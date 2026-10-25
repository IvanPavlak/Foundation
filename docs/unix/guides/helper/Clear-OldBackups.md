# Clear-OldBackups

Prunes the backup sink `Backups/Unix` by the three retention limits of `backups.conf`, never
deleting the newest backup of any key; only folders named `yyyy-MM-dd_HH-mm-ss` count as backups.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`backups.conf`](../../configuration.md#files) | `max-age-days N` | `0` (off) | Backups older than N days are removed |
| [`backups.conf`](../../configuration.md#files) | `max-backups-per-key N` | `10` | Only the N newest backups of each key are kept; also enforced right after every backup |
| [`backups.conf`](../../configuration.md#files) | `max-total-size-mb N` | `500` | The oldest backups are removed while the whole sink is larger than N MB |

## Decisions

1. Should backups expire by age?
    - Options: `max-age-days N` with a whole number of days, or `0` to keep backups whatever their age.
    - Default: `0`, off: a replaced original is kept until another limit removes it.
    - More detail: [`backups.conf`](../../configuration.md#files)
2. How many backups of one file or folder (one key) should be kept?
    - Options: `max-backups-per-key N`, or `0` for no limit.
    - Default: `10`; every new backup also trims its own key to this number.
    - More detail: [`backups.conf`](../../configuration.md#files)
3. How large may the whole sink grow?
    - Options: `max-total-size-mb N`, or `0` for no cap; the oldest backups go first.
    - Default: `500` MB.
    - More detail: [`backups.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/backups.local.conf`, created when missing. The file has no sections: its lines are
added after the base ones and the last line of a key wins, so one line per key you change is
enough. Every value must be a whole number (`0` turns a limit off); anything else stops the
command. The flags `--max-age-days`, `--max-backups-per-key` and `--max-total-size-mb` override a
value for one run. An `@TYPE` prefix gives a machine type its own limit.

## Steps Overview

1. Set the retention limits
2. Check the configuration

## Step 1: Set the retention limits

```conf
max-age-days          90
max-backups-per-key   5
@Laptop max-total-size-mb 200
```

## Step 2: Check the configuration

```bash
Clear-OldBackups --dry-run
```

The dry run lists every backup the limits would remove, with the reason, and deletes nothing.
`Test-ConfigurationSchema` does not check this file.

## Verification

```bash
cat Unix/config/backups.local.conf
Clear-OldBackups --dry-run
```

## Complete Example

`Unix/config/backups.local.conf`:

```conf
max-age-days          90
max-backups-per-key   5
max-total-size-mb     1000
@Laptop max-total-size-mb 200
```

## Related

- [`Clear-OldBackups` in the Helper module reference](../../modules/Helper.md#clear-oldbackups)
- [Helper configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
