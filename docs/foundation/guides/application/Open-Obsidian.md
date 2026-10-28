# Open-Obsidian

Opens Obsidian on the vault of `obsidian.conf` and, when a workspace resolves, loads that saved
Obsidian workspace through the Obsidian CLI.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`obsidian.conf`](../../configuration.md#files) | `directory PATH` | `~/Documents/Obsidian` | The vault folder; its `.obsidian/workspaces.json` lists the saved workspaces. `OBSIDIAN_DIRECTORY` in the environment wins |
| [`obsidian.conf`](../../configuration.md#files) | `vault NAME` | none: the folder name of `directory` | The vault the CLI and the `obsidian://open` link address; `--vault NAME` overrides it for one run |
| [`obsidian.conf`](../../configuration.md#files) | `default-workspace NAME` | none: Obsidian restores its last layout | The saved Obsidian workspace a cold start loads when nothing else chose one |
| [`apps.conf`](../../configuration.md#files) | `app Obsidian BUNDLE-ID` | `app Obsidian md.obsidian` | The app launched when opening the vault by link fails |

## Decisions

1. Where is the vault?
    - Options: `directory PATH` (`~`, `$DEV` and `$VARIABLES` expand), or `OBSIDIAN_DIRECTORY` in the environment.
    - Default: `~/Documents/Obsidian`. With neither `directory` nor `vault` set, Open-Obsidian stops with a configuration error.
    - More detail: [`obsidian.conf`](../../configuration.md#files)
2. Does the vault's name differ from its folder name?
    - Options: `vault NAME`, the name Obsidian shows for the vault.
    - Default: the folder name of `directory`.
    - More detail: [`obsidian.conf`](../../configuration.md#files)
3. Which saved workspace should a cold start load when nothing else chooses one?
    - Options: `default-workspace NAME`, a workspace saved with Obsidian's core Workspaces plugin. It applies only when Obsidian is not running and no `--workspace`, matching Foundation workspace name or menu pick chose one.
    - Default: empty; Obsidian restores its last layout.
    - More detail: [`obsidian.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/obsidian.local.conf`, created when missing. The file has no sections: its lines are
added after the base ones and the last line for this machine type wins, so an overlay
`directory` replaces the base one. `@TYPE` gives each machine type its own value
(`@Laptop default-workspace MyProject`). Loading a workspace needs the CLI switched on once with
[Enable-ObsidianCli](Enable-ObsidianCli.md).

## Steps Overview

1. Point at the vault
2. Choose the default workspace
3. Check the configuration

## Step 1: Point at the vault

```conf
directory ~/Documents/Obsidian/MyVault
vault MyVault
```

## Step 2: Choose the default workspace

```conf
default-workspace MyProject
```

A workspace whose name equals a Foundation workspace's is loaded during that workspace's open
(`w MyProject`) without any line here.

## Step 3: Check the configuration

```bash
ls ~/Documents/Obsidian/MyVault/.obsidian/workspaces.json
Enable-ObsidianCli --check
```

The first shows the vault has saved workspaces; the second that the CLI can load them.

## Verification

```bash
cat Unix/config/obsidian.local.conf
ls ~/Documents/Obsidian/MyVault/.obsidian/workspaces.json
Enable-ObsidianCli --check
```

## Complete Example

`Unix/config/obsidian.local.conf`:

```conf
directory ~/Documents/Obsidian/MyVault
vault MyVault
default-workspace MyProject
@Laptop default-workspace Notes
```

## Related

- [`Open-Obsidian` in the Application module reference](../../modules/Application.md#open-obsidian)
- [Enable-ObsidianCli](Enable-ObsidianCli.md)
- [Application configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
