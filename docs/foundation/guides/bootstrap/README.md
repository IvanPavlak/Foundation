# Bootstrap Module Configuration Guides

The Bootstrap module provisions a Mac: the Bootstrap runner and the commands its steps run (the
first-run identity, system defaults, power, Dock, login items, .NET, Conda, NuGet, npm and Docker
Desktop's tools). See
[the module reference](../../modules/Bootstrap.md).

## Configurable Commands

| Command | Configuration files | Guide |
| ------- | ------------------- | ----- |
| `Bootstrap` | `bootstrap.conf`, `git.conf`, `machines.conf`, `language.conf` | [Bootstrap](Bootstrap.md) |
| `Configure-DockerDesktop` | `docker.conf` | [Configure-DockerDesktop](Configure-DockerDesktop.md) |
| `Configure-NpmConfig` | `npm.conf` | [Configure-NpmConfig](Configure-NpmConfig.md) |
| `Configure-NuGetConfig` | `dotnet.conf` | [Configure-NuGetConfig](Configure-NuGetConfig.md) |
| `Initialize-Configuration` | `git.conf`, `machines.conf` | [Initialize-Configuration](Initialize-Configuration.md) |
| `Install-CondaEnvironments` | `conda-environments.conf` | [Install-CondaEnvironments](Install-CondaEnvironments.md) |
| `Install-DotnetEf` | `dotnet.conf` | [Install-DotnetEf](Install-DotnetEf.md) |
| `Install-DotnetSdks` | `dotnet.conf`, `bootstrap.conf` | [Install-DotnetSdks](Install-DotnetSdks.md) |
| `Set-DockPins` | `dock.conf` | [Set-DockPins](Set-DockPins.md) |
| `Set-LoginItems` | `login-items.conf` | [Set-LoginItems](Set-LoginItems.md) |
| `Set-PowerSettings` | `power.conf` | [Set-PowerSettings](Set-PowerSettings.md) |
| `Set-SystemDefaults` | `system-defaults.conf` | [Set-SystemDefaults](Set-SystemDefaults.md) |

## Commands With No Configuration

[Deploy-FirefoxProfile](Deploy-FirefoxProfile.md)

## Related

- [All configuration guides](../README.md)
- [Configuration](../../configuration.md)
- [Bootstrap a Mac](../../bootstrap.md)
