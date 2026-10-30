# Configure-NuGetConfig

Writes the NuGet config template to the user's NuGet config with a GitHub username and personal
access token, asked on the terminal, filled in for its `[Username]` and `[Token]` placeholders.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`dotnet.conf`](../../configuration.md#dotnetconf-and-conda-environmentsconf) | `nuget-template PATH` | `NuGet/nuget.config` | The template with `[Username]` and `[Token]` placeholders; a relative path starts at the repository root |
| [`dotnet.conf`](../../configuration.md#dotnetconf-and-conda-environmentsconf) | `nuget-config PATH` | `~/.nuget/NuGet/NuGet.Config` | Where the filled-in config is written; `~` and `$VARIABLES` expand, and a relative path starts at the repository root |

## Decisions

1. Which NuGet config template holds your package sources?
    - Options: a path to a NuGet config whose credentials read `[Username]` and `[Token]`, relative to the repository root or absolute (`$DEV/MyRepo/nuget.config`).
    - Default: `NuGet/nuget.config` of the repository.
    - More detail: [`dotnet.conf`](../../configuration.md#dotnetconf-and-conda-environmentsconf)
2. Where should the filled-in config go?
    - Options: any path NuGet reads; the user-wide config is the usual one.
    - Default: `~/.nuget/NuGet/NuGet.Config`.
    - More detail: [`dotnet.conf`](../../configuration.md#dotnetconf-and-conda-environmentsconf)
3. Should Bootstrap run it?
    - Options: `step NuGetConfig on` in `bootstrap.local.conf` (it asks on the terminal, so it is off by default), per machine type with `@TYPE`.
    - Default: off; run `Configure-NuGetConfig` by hand.
    - More detail: [Bootstrap](Bootstrap.md)

## Where to Put Values

`Unix/config/dotnet.local.conf`, created when missing. Its lines go before any section and are
read after the base ones, so its `nuget-template` and `nuget-config` win; an `@TYPE` prefix limits
a line to one machine type. The username and token are never stored in configuration: they are
asked each time the config is written.

## Steps Overview

1. Point at the template and the destination
2. Check the configuration

## Step 1: Point at the template and the destination

```conf
nuget-template NuGet/nuget.config
nuget-config ~/.nuget/NuGet/NuGet.Config
```

The template's `<packageSources>` decide whether a rerun rewrites the file: when the existing
config has the same sources (key and URL), nothing changes; `--override` rewrites it anyway. An
existing file is backed up into `Backups/Unix/System/NuGetConfig/` first, with every
`ClearTextPassword` and `Password` value replaced by `REDACTED`, so the copy holds no token.

## Step 2: Check the configuration

```bash
Configure-NuGetConfig --dry-run
```

It names the template and the destination, compares their package sources and asks nothing. A
missing template stops it with the path it looked for.

## Verification

```bash
Configure-NuGetConfig --dry-run
Bootstrap --only NuGetConfig --dry-run
Test-ConfigurationSchema --quiet
```

## Complete Example

`Unix/config/dotnet.local.conf`:

```conf
nuget-template NuGet/nuget.config
nuget-config ~/.nuget/NuGet/NuGet.Config
@Work nuget-template $DEV/MyRepo/nuget.config
```

## Related

- [`Configure-NuGetConfig` in the Bootstrap module reference](../../modules/Bootstrap.md#configure-nugetconfig)
- [Bootstrap configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
