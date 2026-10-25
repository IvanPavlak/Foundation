# Add-BrowserGroup

Adds a browser URL group as a new `[GROUP]` section of `browser-groups.local.conf`, the group
`Open-Browser` and a workspace's `Open-Browser` line open as the tabs of one window.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`browser-groups.conf`](../../configuration.md#browser-groupsconf) | `[Group]` | `[Google]`, `[AI]`, `[Email]`, `[Calendar]`, `[News]`, `[YouTube]` | A group; a dotted name nests (`[GitHub.Personal]`), and a group opens its own URLs plus every nested group's. Add-BrowserGroup writes the section and refuses a name that already exists in the base file or the overlay |
| [`browser-groups.conf`](../../configuration.md#browser-groupsconf) | `Name URL` | the labelled AI URLs (`Claude https://claude.ai/new`, ...) | A labelled URL, written for each `LABEL=URL` argument; the label is addressable on its own (`Open-Browser Name`) |
| [`browser-groups.conf`](../../configuration.md#browser-groupsconf) | `URL` | the plain Google, Calendar, News and YouTube URLs | A plain URL, written for each bare `http...` or `file:...` argument |

## Decisions

1. What should the group be called, and does it nest under another group?
    - Options: any name without `[` or `]`; a dotted name (`MyGroup.Docs`) nests under `MyGroup`, which then opens the nested URLs too. Lookup is the dotted path, then the last segment, then a URL label, all case-insensitive.
    - Default: none; the name is the first argument that is not a URL. A name already in the base file or the overlay is refused and nothing is written.
    - More detail: [`browser-groups.conf`](../../configuration.md#browser-groupsconf)
2. Should each URL carry a label?
    - Options: `LABEL=URL` writes `LABEL URL`, so `Open-Browser LABEL` opens that one URL; a bare URL writes the URL alone.
    - Default: labels are recommended (the `-Urls` form of Windows); bare URLs are the `-SimpleUrls` form.
    - More detail: [`browser-groups.conf`](../../configuration.md#browser-groupsconf)
3. Which URL goes first?
    - Options: the arguments are written in the order given.
    - Default: the first argument's URL. The first URL decides the window title a layout entry matches, so keep a layout's title pattern in step with it.
    - More detail: [Layouts](../../configuration.md#files)

## Where to Put Values

`Unix/config/browser-groups.local.conf`, created with a header when missing and backed up into
`Backups/Unix/Config/` before every later write (nothing is written when the backup fails).
Add-BrowserGroup only appends new sections. To change a group of the base file (`[AI]`), write a
section of the same name in the overlay by hand: it replaces the base one whole, so copy every
line you keep. `@TYPE` limits a line to machine types (`@Work Name URL`).

## Steps Overview

1. Add the group
2. Check the configuration

## Step 1: Add the group

```bash
Add-BrowserGroup MyGroup MyRepo=https://github.com/MyUser/MyRepo Docs=https://example.com/docs
```

writes:

```conf
[MyGroup]
MyRepo https://github.com/MyUser/MyRepo
Docs https://example.com/docs
```

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `Open-Browser` line of `workspaces.conf` (and a `browser` line of `dnd.conf`) that
names no group, group segment or URL label.

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n -A3 '^\[MyGroup\]' Unix/config/browser-groups.local.conf
```

## Complete Example

`Unix/config/browser-groups.local.conf`:

```conf
[MyGroup]
MyRepo https://github.com/MyUser/MyRepo
Docs https://example.com/docs

[MyGroup.Board]
https://example.com/board

[Research]
@Laptop https://example.com/reading-list
https://example.com/papers
```

`Open-Browser MyGroup` opens the `MyGroup` and `MyGroup.Board` URLs; `Open-Browser MyRepo` opens
the one labelled URL.

## Related

- [`Add-BrowserGroup` in the Configuration module reference](../../modules/Configuration.md#add-browsergroup)
- [Configuration configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
