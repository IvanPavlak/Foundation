# Open-ClaudeDesktop

Opens the Claude desktop app unless AeroSpace lists a window of it, through
[Open-Application](Open-Application.md) with the `Claude` app of `apps.conf`; arguments go to the
app.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`apps.conf`](../../configuration.md#files) | `app Claude BUNDLE-ID` | `app Claude com.anthropic.claudefordesktop` | The bundle id launched; without the line the command fails with "apps.conf has no entry for [Claude]" |

## Decisions

1. Does the Claude desktop app on this machine have the standard bundle id?
    - Options: keep the base line, or replace it when the installed app reports another id (`osascript -e 'id of app "Claude"'`).
    - Default: `com.anthropic.claudefordesktop`.
    - More detail: [`apps.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/apps.local.conf`, created when missing. The last `app Claude` line wins, so an
overlay line replaces the base one; no `-LINE` is needed. Nothing needs to change for a standard
install.

## Steps Overview

1. Replace the app line, only when needed
2. Check the configuration

## Step 1: Replace the app line, only when needed

```conf
app Claude com.example.MyClaudeBuild
```

## Step 2: Check the configuration

```bash
osascript -e 'id of app "Claude"'
grep -n 'Claude' Unix/config/apps.conf Unix/config/apps.local.conf
```

The id the first command prints must match the last `app Claude` line.

## Verification

```bash
osascript -e 'id of app "Claude"'
grep -n 'Claude' Unix/config/apps.conf Unix/config/apps.local.conf
```

## Complete Example

`Unix/config/apps.local.conf`:

```conf
app Claude com.example.MyClaudeBuild
```

## Related

- [`Open-ClaudeDesktop` in the Application module reference](../../modules/Application.md#open-claudedesktop)
- [Open-Application](Open-Application.md)
- [Application configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
