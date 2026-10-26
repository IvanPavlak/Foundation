# Open-Browser

Opens browser groups of `browser-groups.conf`, one new browser window per group with its URLs as
tabs, in the browser `apps.conf` names; a group already open is skipped.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`browser-groups.conf`](../../configuration.md#browser-groupsconf) | `[Group]`, `[Group.Nested]` | `[Google]`, `[AI]`, `[Email]`, `[Calendar]`, `[News]`, `[YouTube]` | A group Open-Browser opens by name; dotted names nest, and a group opens its own URLs plus every nested group's. The menu shows them all as a tree (`1`, `1.2`, ...), nested groups and named URLs under their group |
| [`browser-groups.conf`](../../configuration.md#browser-groupsconf) | `URL`, `Name URL` | the URLs of the example groups | A tab of the group; a named URL is also addressable on its own. The first URL decides the window title layouts match |
| [`apps.conf`](../../configuration.md#files) | `default-browser TOKEN` | `Firefox` | The browser used without `--browser TOKEN` |
| [`apps.conf`](../../configuration.md#files) | `browser TOKEN NEW-WINDOW-ARG [PRIVATE-ARG] [launch=open\|launch=script]` | lines for Firefox, TorBrowser, Chrome, Brave, Edge and Safari | How a browser opens a new and a private window, and how it is started: its binary (default), LaunchServices (`launch=open`) or the browser scripting driver (`launch=script`, Safari) |
| [`apps.conf`](../../configuration.md#files) | `app TOKEN BUNDLE-ID [BINARY]` | the browsers with their binaries | The browser's bundle id and the binary Open-Browser starts (every browser except a `launch=script` one needs it) |

## Decisions

1. Which browser groups should exist?
    - Options: one `[Group]` section per group, `[Parent.Child]` for nested ones; lines are `URL` or `Name URL`. A group is looked up by its exact dotted path, then by its last segment, then as a named URL.
    - Default: the example groups Google, AI, Email, Calendar, News and YouTube, which the base workspaces open.
    - More detail: [`browser-groups.conf`](../../configuration.md#browser-groupsconf)
2. Which URL should come first in each group?
    - Options: the URL whose page title a layout entry should match (`2 Right Browser *MyProject*`).
    - Default: the file order.
    - More detail: [`browser-groups.conf`](../../configuration.md#browser-groupsconf)
3. Which browser opens the groups?
    - Options: `default-browser TOKEN`, one of Firefox, Chrome, Brave, Edge, Safari, TorBrowser (any token with `app` and `browser` lines); `--browser TOKEN` for one run. Safari and the Chromium browsers find an open group from their tabs, including one opened by hand; Firefox only knows the windows Open-Browser opened, so a group opened there by hand opens again on a rerun (no title guess, by decision).
    - Default: Firefox.
    - More detail: [`apps.conf`](../../configuration.md#files)
4. Does a browser need other launch arguments?
    - Options: a `browser` line with its new-window and private-window arguments and `launch=open` (Chromium browsers, which macOS refuses their profile when run from a terminal) or `launch=script` (Safari).
    - Default: the base lines; a browser without one gets `--new-window`, no private argument, and its binary.
    - More detail: [`apps.conf`](../../configuration.md#files)

## Where to Put Values

Groups go in `Unix/config/browser-groups.local.conf`, created when missing: a `[Group]` section
there adds the group, and a section with the name of a base one (`[AI]`) replaces it whole, so
copy every URL you keep. `Add-BrowserGroup` writes such a section for you. Browser settings go in
`Unix/config/apps.local.conf`, whose lines are added after the base ones, and the last line
wins: the last `default-browser` line, and the last `app` and `browser` line of a token, so an
overlay line replaces the base one without `-LINE`. A `browser` line is read whole: one without
`launch=` starts the binary. `@TYPE` limits any line to machine types.

## Steps Overview

1. Add the browser groups
2. Choose the browser
3. Check the configuration

## Step 1: Add the browser groups

```conf
[MyProject]
MyRepo https://git.example/MyUser/MyRepo
https://docs.example/MyProject

[MyProject.Api]
Swagger https://localhost:5001/swagger
```

`Open-Browser MyProject` opens all three URLs in one window; `Open-Browser Api` or
`Open-Browser MyRepo` opens just that part.

## Step 2: Choose the browser

```conf
default-browser Chrome
```

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `Open-Browser` workspace action that names a group `browser-groups.conf` does not
have.

## Verification

```bash
Test-ConfigurationSchema --quiet
cat Unix/config/browser-groups.local.conf
grep -n 'browser' Unix/config/apps.local.conf
```

## Complete Example

`Unix/config/browser-groups.local.conf`:

```conf
[MyProject]
MyRepo https://git.example/MyUser/MyRepo
https://docs.example/MyProject

[MyProject.Api]
Swagger https://localhost:5001/swagger

[AI]
Assistant https://assistant.example/
@Work Research https://research.example/
```

`Unix/config/apps.local.conf`:

```conf
default-browser Chrome
@Laptop default-browser Safari
browser Firefox -new-window -private-window launch=open
app MyBrowser com.example.MyBrowser /Applications/MyBrowser.app/Contents/MacOS/MyBrowser
browser MyBrowser --new-window --incognito launch=open
```

## Related

- [`Open-Browser` in the Application module reference](../../modules/Application.md#open-browser)
- [Invoke-Browser](Invoke-Browser.md)
- [Application configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
