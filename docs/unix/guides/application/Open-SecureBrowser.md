# Open-SecureBrowser

Opens Tor Browser with the given URLs, or a private window of the default browser when Tor Browser
is not installed; the SecureBrowser workspace action.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`apps.conf`](../../configuration.md#files) | `app TorBrowser BUNDLE-ID [BINARY]` | `app TorBrowser org.torproject.torbrowser ...` | The bundle id Tor Browser is launched by. Whether it is installed is not configurable: the command checks the fixed path `/Applications/Tor Browser.app`, then asks Spotlight for an app of the bundle id `org.torproject.torbrowser` |
| [`apps.conf`](../../configuration.md#files) | `default-browser TOKEN` | `Firefox` | The fallback browser without Tor Browser |
| [`apps.conf`](../../configuration.md#files) | `app TOKEN BUNDLE-ID [BINARY]` | the browsers with their binaries | The fallback browser's bundle id and binary; every browser except a `launch=script` one (Safari) needs the `BINARY` |
| [`apps.conf`](../../configuration.md#files) | `browser TOKEN NEW-WINDOW-ARG PRIVATE-ARG [launch=open\|launch=script]` | `-private-window` for Firefox, `--incognito` for Chrome and Brave, `-inprivate` for Edge, `launch=open` for the Chromium browsers, `launch=script` for Safari | The private-window argument of the fallback browser (`--private-window` when the line gives none) and how it starts, as in [Open-Browser](Open-Browser.md): its binary, LaunchServices (`launch=open`) or the browser scripting driver (`launch=script`, which has no private window: a warning and a normal one) |

## Decisions

1. Which browser should stand in when Tor Browser is not installed?
    - Options: the `default-browser TOKEN`, started the way Open-Browser starts it: an `app` line with a `BINARY` and a `browser` line with a private-window argument (Firefox, or Chrome, Brave, Edge through LaunchServices with `launch=open`), or Safari through the scripting driver, which opens a normal window with a warning.
    - Default: Firefox.
    - More detail: [`apps.conf`](../../configuration.md#files)
2. Should this machine use Tor Browser at all?
    - Options: install it (`brew install --cask tor-browser`) or leave it out and accept the private-window fallback, which the command announces with a warning.
    - Default: the fallback, until `/Applications/Tor Browser.app` exists or Spotlight knows a Tor Browser elsewhere (such as `~/Applications`), found by its bundle id `org.torproject.torbrowser`.
    - More detail: [`apps.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/apps.local.conf`, created when missing. Its lines are added after the base ones, and
the last line for this machine type wins: the last `default-browser` line, and the last `app` and
`browser` line of a token, so an overlay line replaces the base one without `-LINE`. A `browser`
line is read whole: one without `launch=` starts the binary. `@TYPE` limits a line to machine
types. The default browser is shared with
[Open-Browser](Open-Browser.md).

## Steps Overview

1. Choose the fallback browser
2. Check the configuration

## Step 1: Choose the fallback browser

```conf
default-browser Firefox
```

## Step 2: Check the configuration

```bash
grep -n 'default-browser\|^browser\|^app' Unix/config/apps.conf Unix/config/apps.local.conf
mdfind "kMDItemCFBundleIdentifier == 'org.torproject.torbrowser'"
```

The browser in effect needs an `app` line with a binary path and a `browser` line.

## Verification

```bash
grep -n 'default-browser' Unix/config/apps.conf Unix/config/apps.local.conf
mdfind "kMDItemCFBundleIdentifier == 'org.torproject.torbrowser'"
```

## Complete Example

`Unix/config/apps.local.conf`:

```conf
default-browser Firefox
@Work default-browser Brave
```

## Related

- [`Open-SecureBrowser` in the Application module reference](../../modules/Application.md#open-securebrowser)
- [Open-Browser](Open-Browser.md)
- [Application configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
