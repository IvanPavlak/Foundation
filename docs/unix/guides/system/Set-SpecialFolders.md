# Set-SpecialFolders

Redirects Downloads (a link to another folder) and the screenshot folder as
`special-folders.conf` says; Bootstrap runs it as the SpecialFolders step.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`special-folders.conf`](../../configuration.md#special-foldersconf) | `folder Downloads PATH` | none | `~/Downloads` becomes a link to PATH; what it holds moves there first, a clashing name kept as `NAME (Downloads)` |
| [`special-folders.conf`](../../configuration.md#special-foldersconf) | `folder Screenshots PATH` | none | `com.apple.screencapture location`; the folder is created when missing |

## Decisions

1. Where should Downloads go?
    - Options: `folder Downloads PATH`; PATH takes `~` and `$VARIABLES` and may contain spaces (`~/Desktop`, `$DEV/Downloads`). The last line for this machine type wins. The first run asks for the terminal's access to the Downloads folder.
    - Default: no line, so `~/Downloads` stays a folder. Removing the line later undoes nothing: `rm ~/Downloads && mkdir ~/Downloads && chmod +a "group:everyone deny delete" ~/Downloads` does.
    - More detail: [`special-folders.conf`](../../configuration.md#special-foldersconf)
2. Where should screenshots be saved?
    - Options: `folder Screenshots PATH`, same path rules.
    - Default: no line, so macOS keeps its own setting (the Desktop unless changed).
    - More detail: [`special-folders.conf`](../../configuration.md#special-foldersconf)

## Where to Put Values

`Unix/config/special-folders.local.conf`, created when missing. `special-folders.conf` has no
sections: the overlay's lines are added after the base lines (the base ships none) and the last
line for a folder wins. `@TYPE` limits a line to machine types (`@Laptop folder Downloads ~/Desktop`).
Any folder name other than Downloads or Screenshots is skipped with a warning.

## Steps Overview

1. Add the `folder` lines
2. Preview the change

## Step 1: Add the `folder` lines

```conf
folder Downloads    ~/Desktop
folder Screenshots  ~/Pictures/Screenshots
```

## Step 2: Preview the change

```bash
Test-ConfigurationSchema --quiet
Set-SpecialFolders --dry-run
```

`Test-ConfigurationSchema` reports an `@TYPE` prefix that names a machine type `machines.conf`
does not have; `--dry-run` prints what would move and what would be written.

## Verification

```bash
Set-SpecialFolders --dry-run
ls -ld ~/Downloads
defaults read com.apple.screencapture location
```

## Complete Example

`Unix/config/special-folders.local.conf`:

```conf
folder Downloads    ~/Desktop
folder Screenshots  ~/Pictures/Screenshots
@Laptop folder Screenshots ~/Desktop
```

## Related

- [`Set-SpecialFolders` in the System module reference](../../modules/System.md#set-specialfolders)
- [System configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
