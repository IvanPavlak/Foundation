# Set-SystemDefaults

Applies the macOS settings of `system-defaults.conf`, one group per section in file order, with
`defaults` writes, folders, other commands, process restarts and printed notes.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`system-defaults.conf`](../../configuration.md#system-defaultsconf) | `[Group]` | Dock, Finder, Keyboard, Trackpad, Screenshots, HotCorners, MenuBar, Windows, Appearance, Apps, Theme | A group of settings, applied in file order and selectable by name (`Set-SystemDefaults Dock`, `--skip Dock`) |
| [`system-defaults.conf`](../../configuration.md#system-defaultsconf) | `defaults DOMAIN KEY TYPE VALUE...` | the groups' preferences | A `defaults write`; TYPE is `-bool` (or `-boolean`), `-int` (or `-integer`), `-float`, `-string`, `-date`, `-data`, `-array`, `-array-add`, `-dict` or `-dict-add` (array and dict values split into words), any other type skips the line with a warning; a KEY with spaces goes in double quotes |
| [`system-defaults.conf`](../../configuration.md#system-defaultsconf) | `currenthost DOMAIN KEY TYPE VALUE...` | the per-host trackpad and battery switches | A `defaults -currentHost write` |
| [`system-defaults.conf`](../../configuration.md#system-defaultsconf) | `delete DOMAIN KEY` | the fixed accent and highlight colours | A `defaults delete`; a missing key is not an error |
| [`system-defaults.conf`](../../configuration.md#system-defaultsconf) | `mkdir PATH` | none | A folder a setting points at, created when missing |
| [`system-defaults.conf`](../../configuration.md#system-defaultsconf) | `command NAME ARGS...` | `Set-SystemTheme --auto --skip SetWallpaper` in `[Theme]` | Another Foundation command run in place |
| [`system-defaults.conf`](../../configuration.md#system-defaultsconf) | `restart PROCESS...` | Dock, Finder, SystemUIServer, ControlCenter | Processes restarted once, at the end, so the changes show |
| [`system-defaults.conf`](../../configuration.md#system-defaultsconf) | `note TEXT` | the log-out reminders | Text printed at the end |

## Decisions

1. Which groups should apply on this Mac?
    - Options: keep the base groups, add your own `[Group]` sections, or turn one off with an empty section of the same name in the overlay.
    - Default: every base group, in file order.
    - More detail: [`system-defaults.conf`](../../configuration.md#system-defaultsconf)
2. Which preferences should a group write?
    - Options: `defaults`, `currenthost` and `delete` lines (`defaults com.apple.dock tilesize -int 40`); the keys and what each needs to take effect are in `Backlog/MacOS/Research/MacOSDefaultsInventory.md`.
    - Default: the base group's lines.
    - More detail: [`system-defaults.conf`](../../configuration.md#system-defaultsconf)
3. Should a setting differ per machine type?
    - Options: an `@TYPE` prefix on the line (`@Laptop defaults com.apple.dock tilesize -int 40`).
    - Default: every line applies everywhere.
    - More detail: [Shared format](../../configuration.md#shared-format)
4. Which processes must restart, and what should the run remind you of?
    - Options: `restart PROCESS...` lines (each process restarts once, whatever the number of lines naming it) and `note TEXT` lines.
    - Default: the base groups restart what they change and remind you to log out for keyboard, trackpad and window changes.
    - More detail: [`system-defaults.conf`](../../configuration.md#system-defaultsconf)
5. Should a group run another command?
    - Options: `command NAME ARGS...` naming a Foundation command; an unknown one is skipped with a warning.
    - Default: `[Theme]` runs `Set-SystemTheme --auto --skip SetWallpaper`.
    - More detail: [`system-defaults.conf`](../../configuration.md#system-defaultsconf)

## Where to Put Values

`Unix/config/system-defaults.local.conf`, created when missing. A `[Group]` there replaces the
base group of that name whole, so copy every line you keep; an empty one turns the group off on
this Mac, and a new name adds a group after the base ones. `@TYPE` limits a line to one machine
type. Write no trailing comment on a data line.

## Steps Overview

1. Override or add a group
2. Check the configuration

## Step 1: Override or add a group

```conf
[Dock]
defaults com.apple.dock orientation -string bottom
defaults com.apple.dock autohide -bool true
@Laptop defaults com.apple.dock tilesize -int 40
restart Dock

[HotCorners]

[MyGroup]
mkdir ~/Pictures/MyFolder
defaults com.apple.print.PrintingPrefs "Quit When Finished" -bool true
note MyGroup changes show after the app is reopened.
```

The empty `[HotCorners]` turns that group off; `[MyGroup]` is a group of your own.

## Step 2: Check the configuration

```bash
Set-SystemDefaults --list
```

It prints every group with the commands it would run, and changes nothing. A group name given
on the command line that the file does not have is reported.

## Verification

```bash
Set-SystemDefaults --list
Set-SystemDefaults Dock --dry-run
Bootstrap --only SystemDefaults --dry-run
Test-ConfigurationSchema --quiet
```

## Complete Example

`Unix/config/system-defaults.local.conf`:

```conf
[Dock]
defaults com.apple.dock orientation -string bottom
defaults com.apple.dock autohide -bool true
@Laptop defaults com.apple.dock tilesize -int 40
@Work defaults com.apple.dock tilesize -int 50
restart Dock

[Trackpad]
currenthost NSGlobalDomain com.apple.mouse.tapBehavior -int 1
note Trackpad changes take effect after logging out.

[HotCorners]

[MyGroup]
mkdir ~/Pictures/MyFolder
delete NSGlobalDomain AppleAccentColor
command Set-SystemTheme --auto
restart Finder
```

## Related

- [`Set-SystemDefaults` in the Bootstrap module reference](../../modules/Bootstrap.md#set-systemdefaults)
- [Bootstrap configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
