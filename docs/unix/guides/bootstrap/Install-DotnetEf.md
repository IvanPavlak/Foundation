# Install-DotnetEf

Installs the EF Core CLI (`dotnet ef`) as a global .NET tool at the version `dotnet.conf` names,
leaving an installed one alone.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`dotnet.conf`](../../configuration.md#dotnetconf-and-conda-environmentsconf) | `ef-version VERSION` | empty: the latest | The dotnet-ef version installed when none is: an exact one (`8.0.11`) or a wildcard (`8.*`) |

## Decisions

1. Which dotnet-ef version should be installed?
    - Options: an exact version (`8.0.11`), a wildcard (`8.*`) matching your projects' EF Core, or an empty `ef-version` for the latest; per machine type with `@TYPE`.
    - Default: the latest version.
    - More detail: [`dotnet.conf`](../../configuration.md#dotnetconf-and-conda-environmentsconf)
2. Should Bootstrap install it on this Mac?
    - Options: keep the DotnetEf step on, or `step DotnetEf off` in `bootstrap.local.conf` (`@TYPE` per machine type).
    - Default: on; without the .NET SDK it does nothing.
    - More detail: [Bootstrap](Bootstrap.md)

## Where to Put Values

`Unix/config/dotnet.local.conf`, created when missing. Its lines are read after the base ones, so
its `ef-version` wins; an `@TYPE` prefix limits it to one machine type. The version only applies
when dotnet-ef is not installed yet: an installed one is left alone, and `--update` moves it to
the latest.

## Steps Overview

1. Set the version
2. Check the configuration

## Step 1: Set the version

```conf
ef-version 8.*
```

## Step 2: Check the configuration

```bash
Install-DotnetEf --dry-run
```

It prints the `dotnet tool install` command with the version, or says dotnet-ef is already
installed.

## Verification

```bash
Install-DotnetEf --dry-run
Bootstrap --only DotnetEf --dry-run
Test-ConfigurationSchema --quiet
```

## Complete Example

`Unix/config/dotnet.local.conf`:

```conf
ef-version 8.*
@Work ef-version 8.0.11
```

## Related

- [`Install-DotnetEf` in the Bootstrap module reference](../../modules/Bootstrap.md#install-dotnetef)
- [Bootstrap configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
