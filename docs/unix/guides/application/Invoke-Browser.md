# Invoke-Browser

Searches Google for a query in a new window of the default browser (`b how to x`), or shows the
browser group menu of [Open-Browser](Open-Browser.md) when no query is given (alias `b`); it hands
both to Open-Browser, so it is configured by the files Open-Browser reads.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`browser-groups.conf`](../../configuration.md#browser-groupsconf) | `[Group]` | `[Google]`, `[AI]`, `[Email]`, `[Calendar]`, `[News]`, `[YouTube]` | The top-level groups a bare `b` offers in its menu |
| [`apps.conf`](../../configuration.md#files) | `default-browser TOKEN` | `Firefox` | The browser a search and the menu open in |
| [`apps.conf`](../../configuration.md#files) | `browser TOKEN NEW-WINDOW-ARG [PRIVATE-ARG] [launch=open\|launch=script]` | lines for Firefox, TorBrowser, Chrome, Brave, Edge and Safari | The new-window argument and the way the browser is started |

## Decisions

1. Which browser should searches open in?
    - Options: `default-browser TOKEN`, one of Firefox, Chrome, Brave, Edge, Safari, TorBrowser.
    - Default: Firefox.
    - More detail: [`apps.conf`](../../configuration.md#files)
2. Which groups should a bare `b` offer?
    - Options: the top-level `[Group]` sections of `browser-groups.conf`; nested `[Group.Child]` sections open with their parent and are not listed.
    - Default: the example groups.
    - More detail: [Open-Browser](Open-Browser.md)

## Where to Put Values

`Unix/config/apps.local.conf` for the browser (the last `default-browser` line for this machine
type wins) and `Unix/config/browser-groups.local.conf` for the groups (a section there adds a
group or replaces the base one of the same name whole). Both are created when missing; `@TYPE`
limits a line to machine types.

## Steps Overview

1. Choose the browser
2. Check the configuration

## Step 1: Choose the browser

```conf
default-browser Chrome
@Laptop default-browser Safari
```

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
grep -n 'default-browser' Unix/config/apps.conf Unix/config/apps.local.conf
```

The last `default-browser` line for this machine type is the one in effect.

## Verification

```bash
grep -n 'default-browser' Unix/config/apps.conf Unix/config/apps.local.conf
grep -n '^\[' Unix/config/browser-groups.conf Unix/config/browser-groups.local.conf
```

## Complete Example

`Unix/config/apps.local.conf`:

```conf
default-browser Chrome
@Laptop default-browser Safari
```

`Unix/config/browser-groups.local.conf`:

```conf
[MyProject]
MyRepo https://git.example/MyUser/MyRepo
https://docs.example/MyProject
```

## Related

- [`Invoke-Browser` in the Application module reference](../../modules/Application.md#invoke-browser)
- [Open-Browser](Open-Browser.md)
- [Application configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
