# Enable-ObsidianCli

Turns on the Obsidian command line interface for this machine (`"cli": true` in Obsidian's own
`obsidian.json`), which [Open-Obsidian](Open-Obsidian.md) needs to load a saved workspace.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`obsidian.conf`](../../configuration.md#files) | `directory PATH` | `~/Documents/Obsidian` | The vault folder Open-Obsidian addresses. No line of `obsidian.conf` changes what Enable-ObsidianCli does: it loads the Obsidian library only to tell whether Obsidian runs, and the switch it sets is machine-wide, in `~/Library/Application Support/obsidian/obsidian.json`, the same for every vault |

## Decisions

1. Should Obsidian on this machine answer the `obsidian` command?
    - Options: run `Enable-ObsidianCli` once with Obsidian quit (`--create-if-missing` when Obsidian never started here), or switch on Settings > General > Advanced > Command line interface by hand.
    - Default: off; Open-Obsidian then opens the vault but cannot load a workspace and says so.
    - More detail: [`obsidian.conf`](../../configuration.md#files)
2. Which vault does the CLI address?
    - Options: the `directory PATH` (and `vault NAME`) lines of `obsidian.conf`, read by Open-Obsidian, not by this command.
    - Default: the vault folder `~/Documents/Obsidian`.
    - More detail: [Open-Obsidian](Open-Obsidian.md)

## Where to Put Values

`Unix/config/obsidian.local.conf`, created when missing, for the vault lines Open-Obsidian reads.
Its lines are added after the base ones and the last line for this machine type wins; `@TYPE`
limits a line to machine types. The CLI switch itself is not a `Unix/config` value: this command
writes it into Obsidian's `obsidian.json`, backed up into `Backups/Unix/Config` first.

## Steps Overview

1. Point the vault lines at your vault
2. Check the configuration

## Step 1: Point the vault lines at your vault

```conf
directory ~/Documents/Obsidian/MyVault
```

## Step 2: Check the configuration

```bash
Enable-ObsidianCli --check
```

It reports whether the CLI is on and changes nothing; it exits non-zero while the CLI is off.

## Verification

```bash
Enable-ObsidianCli --check
cat Unix/config/obsidian.local.conf
```

## Complete Example

`Unix/config/obsidian.local.conf`:

```conf
directory ~/Documents/Obsidian/MyVault
```

## Related

- [`Enable-ObsidianCli` in the Application module reference](../../modules/Application.md#enable-obsidiancli)
- [Open-Obsidian](Open-Obsidian.md)
- [Application configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
