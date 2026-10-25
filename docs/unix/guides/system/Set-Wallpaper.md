# Set-Wallpaper

Sets the wallpaper of every display from `wallpapers.conf`: the `[Dark]` or `[Light]` line of
this machine type, following the system appearance by default.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`wallpapers.conf`](../../configuration.md#files) | `directory PATH` | `$DOTFILES_ROOT/Wallpapers` | Where a relative wallpaper file lives |
| [`wallpapers.conf`](../../configuration.md#files) | `[Dark]`, `[Light]` | both, with `Test` and `Default` lines | The wallpapers of each theme; a missing section stops the run for that theme |
| [`wallpapers.conf`](../../configuration.md#files) | `MACHINE FILE [FILE...]` | `Test` and `Default`: `Black.jpg` (Dark), `White.png` (Light) | The pictures of machine type MACHINE, one per display in display order, cycling when there are more displays; `Default` serves every machine type without a line |

## Decisions

1. Where do the wallpaper files live?
    - Options: `directory PATH` (`~` and `$VARIABLES` expand), or full paths on the machine lines (a FILE starting with `/`, `~` or `$` is used as is).
    - Default: the repository's `Wallpapers/` folder.
    - More detail: [`wallpapers.conf`](../../configuration.md#files)
2. Which pictures should each machine type get in Dark and in Light?
    - Options: a `MACHINE FILE [FILE...]` line per machine type in `[Dark]` and in `[Light]`; several files go to the displays in order, a path with spaces goes in double quotes, and a file that does not exist stops the run.
    - Default: the `Default` line of the section, else nothing is set (a warning).
    - More detail: [`wallpapers.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/wallpapers.local.conf`, created when missing. The `directory` line goes before the
first section (the last one wins). A `[Dark]` or `[Light]` section there replaces the base one
whole, so copy the `Default` line (and any other you keep) into it.

## Steps Overview

1. Add the pictures
2. Add the theme sections
3. Check the configuration

## Step 1: Add the pictures

Put the files in the `directory` (the repository's `Wallpapers/` by default), or set a folder of
your own:

```conf
directory ~/Pictures/Wallpapers
```

## Step 2: Add the theme sections

```conf
[Dark]
Work     MyDark-Left.jpg MyDark-Right.jpg
Default  MyDark.jpg

[Light]
Work     MyLight.png
Default  MyLight.png
```

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `@TYPE` prefix that names a machine type `machines.conf` does not have; a missing
picture shows in the dry run below.

## Verification

```bash
Test-ConfigurationSchema --quiet
Set-Wallpaper --theme Dark --dry-run
Set-Wallpaper --theme Light --dry-run
```

## Complete Example

`Unix/config/wallpapers.local.conf`:

```conf
directory ~/Pictures/Wallpapers

[Dark]
Work     MyDark-Left.jpg MyDark-Right.jpg
Laptop   "My Dark Wallpaper.jpg"
Default  MyDark.jpg

[Light]
Work     MyLight.png
Default  MyLight.png
```

## Related

- [`Set-Wallpaper` in the System module reference](../../modules/System.md#set-wallpaper)
- [Set-SystemTheme](Set-SystemTheme.md)
- [System configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
