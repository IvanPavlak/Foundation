# Open-T3Code

Opens the T3 Code desktop app unless AeroSpace lists a window of it, through
[Open-Application](Open-Application.md) with the `T3Code` app of `apps.conf`; arguments go to the
app.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`apps.conf`](../../configuration.md#files) | `app T3Code BUNDLE-ID` | `app T3Code com.t3tools.t3code` | The bundle id launched; without the line the command fails with "apps.conf has no entry for [T3Code]" |

## Decisions

1. Does the T3 Code desktop app on this machine have the standard bundle id?
    - Options: keep the base line, or replace it when the installed app reports another id (`osascript -e 'id of app "T3 Code (Beta)"'`).
    - Default: `com.t3tools.t3code`.
    - More detail: [`apps.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/apps.local.conf`, created when missing. The last `app T3Code` line wins, so an
overlay line replaces the base one; no `-LINE` is needed. Nothing needs to change for a standard
install.

## Steps Overview

1. Replace the app line, only when needed
2. Check the configuration

## Step 1: Replace the app line, only when needed

```conf
app T3Code com.example.MyT3CodeBuild
```

## Step 2: Check the configuration

```bash
osascript -e 'id of app "T3 Code (Beta)"'
grep -n 'T3Code' Unix/config/apps.conf Unix/config/apps.local.conf
```

The id the first command prints must match the last `app T3Code` line.

## Verification

```bash
osascript -e 'id of app "T3 Code (Beta)"'
grep -n 'T3Code' Unix/config/apps.conf Unix/config/apps.local.conf
```

## Complete Example

`Unix/config/apps.local.conf`:

```conf
app T3Code com.example.MyT3CodeBuild
```

## Related

- [`Open-T3Code` in the Application module reference](../../modules/Application.md#open-t3code)
- [Open-Application](Open-Application.md)
- [Application configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
