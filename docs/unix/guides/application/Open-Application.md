# Open-Application

Launches an app of `apps.conf` by its token unless AeroSpace lists a window of it (without
AeroSpace the app is always opened, which brings a running instance forward); the generic launcher
behind every `Open-<App>` workspace action without a dedicated command (`Open-Slack`,
`Open-DBeaver`).

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`apps.conf`](../../configuration.md#files) | `app TOKEN BUNDLE-ID [BINARY]` | Code, Claude, WezTerm, Ghostty, the browsers, Obsidian, WhatsApp, Mail, DBeaver, Discord, Acrobat, Slack, Steam, TeamViewer, VirtualBox, VMware, Finder, Docker, OBS | The apps Open-Application can launch: `TOKEN` is the name it is called by (a bundle id works too, any case), `BUNDLE-ID` what `open -b` launches. Each line also enables the `Open-<TOKEN>` workspace action |

## Decisions

1. Which applications should Open-Application (and an `Open-<App>` workspace line) know?
    - Options: one `app TOKEN BUNDLE-ID` line per app; find the bundle id with `osascript -e 'id of app "MyApp"'`. `BINARY` is needed only by browsers.
    - Default: the base list.
    - More detail: [`apps.conf`](../../configuration.md#files)
2. Should an app exist only on some machine types?
    - Options: prefix its line with `@TYPE` (`@Work app MyApp com.example.MyApp`).
    - Default: every line applies everywhere.
    - More detail: [Shared format](../../configuration.md#shared-format)

## Where to Put Values

`Unix/config/apps.local.conf`, created when missing. Its lines are added after the base ones, and
the last `app` line of a token (any case) wins, so an overlay line with a base token changes that
app's bundle id; no `-LINE` is needed. `@TYPE` limits a line to machine types.

## Steps Overview

1. Add the app line
2. Check the configuration

## Step 1: Add the app line

```conf
app MyApp com.example.MyApp
```

`Open-Application MyApp`, or an `Open-MyApp` line in a workspace, now launches it.

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports a workspace `Open-<App>` action whose app has no `app` line, and a layout entry naming
an unknown token.

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n '^app' Unix/config/apps.local.conf
osascript -e 'id of app "MyApp"'
```

## Complete Example

`Unix/config/apps.local.conf`:

```conf
app MyApp com.example.MyApp
@Work app MyWorkApp com.example.MyWorkApp
app Acrobat com.adobe.Acrobat.Pro
```

## Related

- [`Open-Application` in the Application module reference](../../modules/Application.md#open-application)
- [Application configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
