# Set-DockPins

Pins the apps and folders of `dock.conf` to the Dock with `dockutil`, either as the Dock's whole
contents or by adding only what is missing.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`dock.conf`](../../configuration.md#dockconf-and-login-itemsconf) | `clear on\|off` | `off` | `on`: the Dock holds exactly the lines of the file, in order; `off`: missing pins are added and the rest stay |
| [`dock.conf`](../../configuration.md#dockconf-and-login-itemsconf) | `pin PATH` | `pin /Applications/WezTerm.app` | An app on the left side, in file order |
| [`dock.conf`](../../configuration.md#dockconf-and-login-itemsconf) | `spacer` | none | A gap between apps (added only when the Dock is rebuilt; with `clear on` it makes every run rebuild the Dock) |
| [`dock.conf`](../../configuration.md#dockconf-and-login-itemsconf) | `folder PATH [OPTION...]` | none | A folder on the right side, with dockutil options (`--view`, `--display`, `--sort`) |

## Decisions

1. Should the Dock hold exactly your list, or keep what is already pinned?
    - Options: `clear on` (the Dock is backed up into `Backups/Unix/System/DockLayout/`, then emptied and refilled when it differs; a list with a `spacer` is refilled on every run, as spacers cannot be compared; when the backup fails the Dock is left as it is) or `clear off` (only missing pins are added).
    - Default: `clear off` in the base file; a file without a `clear` line behaves the same.
    - More detail: [`dock.conf`](../../configuration.md#dockconf-and-login-itemsconf)
2. Which apps go in the Dock, in which order?
    - Options: one `pin PATH` line per app (`pin /Applications/MyApp.app`, spaces allowed), `spacer` lines between them, `@TYPE` for one machine type.
    - Default: WezTerm; an app that is not installed is skipped with a warning.
    - More detail: [`dock.conf`](../../configuration.md#dockconf-and-login-itemsconf)
3. Which folders go on the right side, and how do they show?
    - Options: `folder PATH` with `--view fan|grid|list|auto`, `--display folder|stack`, `--sort name|dateadded|datemodified|datecreated|kind`.
    - Default: none.
    - More detail: [`dock.conf`](../../configuration.md#dockconf-and-login-itemsconf)

## Where to Put Values

`Unix/config/dock.local.conf`, created when missing. Its lines are read after the base ones: a
`clear` line there wins (the last one counts), its `pin`, `spacer` and `folder` lines follow the
base ones, and `-LINE` takes a base line back (`-pin /Applications/WezTerm.app`). `@TYPE` limits
a line to one machine type.

## Steps Overview

1. Choose the clear mode
2. List the pins and folders
3. Check the configuration

## Step 1: Choose the clear mode

```conf
clear on
```

## Step 2: List the pins and folders

```conf
pin /Applications/Visual Studio Code.app
spacer
pin /Applications/MyApp.app
folder ~/Downloads --view fan --display stack --sort dateadded
```

With spacers in the list and `clear on`, every run rebuilds the Dock: a spacer cannot be compared
with what is pinned. Each rebuild first backs up the Dock's preferences; to go back to the Dock
before a rebuild:

```bash
defaults import com.apple.dock ~/Development/Github/MyRepo/Backups/Unix/System/DockLayout/<timestamp>/com.apple.dock.plist
killall Dock
```

## Step 3: Check the configuration

```bash
Set-DockPins --list
```

It shows the Dock today next to the file and the clear mode, and changes nothing.

## Verification

```bash
Set-DockPins --list
Set-DockPins --dry-run
Bootstrap --only DockPins --dry-run
Test-ConfigurationSchema --quiet
```

## Complete Example

`Unix/config/dock.local.conf`:

```conf
clear on
pin /Applications/Visual Studio Code.app
pin /Applications/MyApp.app
spacer
@Work pin /Applications/MyWorkApp.app
folder ~/Downloads --view fan --display stack
```

## Related

- [`Set-DockPins` in the Bootstrap module reference](../../modules/Bootstrap.md#set-dockpins)
- [Bootstrap configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
