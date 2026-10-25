# Install-DotnetSdks

Installs the .NET SDK channels no Homebrew cask ships (such as 6.0) with Microsoft's
`dotnet-install.sh`, into the dotnet root of the cask SDKs, so `dotnet --list-sdks` lists them
together.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`dotnet.conf`](../../configuration.md#dotnetconf-and-conda-environmentsconf) | `sdk-channel CHANNEL` | none | A .NET SDK channel to install when `dotnet --list-sdks` does not list it yet (`6.0`); one line per channel |
| [`bootstrap.conf`](../../configuration.md#files) | `step DotnetSdks on\|off` | `off` | Whether Bootstrap runs it; it needs the administrator password (the dotnet root belongs to root) |

## Decisions

1. Which SDK channels do your projects need that Homebrew does not ship?
    - Options: one `sdk-channel CHANNEL` line each (`sdk-channel 6.0`); `@TYPE` per machine type. The current, 8 and 9 SDKs come from the `dotnet-sdk` casks of the Brewfile instead.
    - Default: none, so it does nothing.
    - More detail: [`dotnet.conf`](../../configuration.md#dotnetconf-and-conda-environmentsconf)
2. Should Bootstrap install them?
    - Options: `step DotnetSdks on` in `bootstrap.local.conf`.
    - Default: off, as every step that needs the administrator password.
    - More detail: [Bootstrap](Bootstrap.md)

## Where to Put Values

`Unix/config/dotnet.local.conf` and `Unix/config/bootstrap.local.conf`, created when missing. The
overlay's `sdk-channel` lines are added to the base ones (which ship none); `-LINE` takes one back
and `@TYPE` limits it to machine types. A channel already installed is left alone.

## Steps Overview

1. Add the channels
2. Turn the step on
3. Check the configuration

## Step 1: Add the channels

```conf
sdk-channel 6.0
```

## Step 2: Turn the step on

`Unix/config/bootstrap.local.conf`:

```conf
step DotnetSdks on
```

## Step 3: Check the configuration

```bash
Install-DotnetSdks --dry-run
```

It prints the `dotnet-install.sh` run for each missing channel, or says the channel is already
installed.

## Verification

```bash
Install-DotnetSdks --dry-run
Bootstrap --only DotnetSdks --dry-run
dotnet --list-sdks
```

## Complete Example

`Unix/config/dotnet.local.conf`:

```conf
sdk-channel 6.0
@Work sdk-channel 7.0
```

`Unix/config/bootstrap.local.conf`:

```conf
step DotnetSdks on
```

## Related

- [`Install-DotnetSdks` in the Bootstrap module reference](../../modules/Bootstrap.md#install-dotnetsdks)
- [Install-DotnetEf](Install-DotnetEf.md)
- [Bootstrap configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
