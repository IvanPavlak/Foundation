# Set-LoginItems

Makes the apps of `login-items.conf` start at login through System Events, adding the missing
ones and never removing any.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`login-items.conf`](../../configuration.md#dockconf-and-login-itemsconf) | `item PATH [hidden]` | `item /Applications/AeroSpace.app hidden` | An app that starts at login; `hidden` starts it without a window |

## Decisions

1. Which apps should start at login?
    - Options: one `item PATH` line per app (`item /Applications/MyApp.app`, spaces allowed), `@TYPE` for one machine type; an app already a login item (compared by name) is left alone.
    - Default: AeroSpace, hidden; an app that is not installed is skipped with a warning.
    - More detail: [`login-items.conf`](../../configuration.md#dockconf-and-login-itemsconf)
2. Should an app start without a window?
    - Options: `hidden` as the last word of its line.
    - Default: the app opens its window.
    - More detail: [`login-items.conf`](../../configuration.md#dockconf-and-login-itemsconf)
3. Should a base item not start on this Mac?
    - Options: `-item PATH [hidden]` in the overlay takes the base line back. Login items already added stay: remove them in System Settings > General > Login Items.
    - Default: every base item is added.
    - More detail: [Shared format](../../configuration.md#shared-format)

## Where to Put Values

`Unix/config/login-items.local.conf`, created when missing. Its `item` lines are added to the base
ones, `-LINE` takes a base line back, and `@TYPE` limits a line to one machine type.

## Steps Overview

1. List the login items
2. Check the configuration

## Step 1: List the login items

```conf
item /Applications/MyApp.app
item /Applications/MyTrayApp.app hidden
```

## Step 2: Check the configuration

```bash
Set-LoginItems --list
```

It shows the login items today and each line of the file as `present`, `missing` or
`not installed`. Like every run, it needs the terminal allowed to control System Events.

## Verification

```bash
Set-LoginItems --list
Set-LoginItems --dry-run
Bootstrap --only LoginItems --dry-run
Test-ConfigurationSchema --quiet
```

## Complete Example

`Unix/config/login-items.local.conf`:

```conf
-item /Applications/AeroSpace.app hidden
item /Applications/AeroSpace.app
item /Applications/MyTrayApp.app hidden
@Work item /Applications/MyWorkApp.app
```

## Related

- [`Set-LoginItems` in the Bootstrap module reference](../../modules/Bootstrap.md#set-loginitems)
- [Bootstrap configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
