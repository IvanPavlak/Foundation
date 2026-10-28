# System Module Configuration Guides

Machine-wide actions (closing everything, the terminal greeting, theme and wallpaper, languages
and keyboard layouts, special folders, Wake-on-LAN, upgrades, the machine name); see
[the module reference](../../modules/System.md).

## Configurable Commands

| Command | Configuration files | Guide |
| ------- | ------------------- | ----- |
| `Determine-DotnetDependencies` | `dotnet.conf` | [Determine-DotnetDependencies](Determine-DotnetDependencies.md) |
| `Display-SystemLanguageSettings` | `language.conf` | [Display-SystemLanguageSettings](Display-SystemLanguageSettings.md) |
| `Invoke-Clear` | `greeting.conf` | [Invoke-Clear](Invoke-Clear.md) |
| `Invoke-Fastfetch` | `greeting.conf` | [Invoke-Fastfetch](Invoke-Fastfetch.md) |
| `Invoke-Onefetch` | `greeting.conf` | [Invoke-Onefetch](Invoke-Onefetch.md) |
| `Kill-All` | `kill-all.conf`, `docker.conf` | [Kill-All](Kill-All.md) |
| `Rename-Machine` | `machines.conf` | [Rename-Machine](Rename-Machine.md) |
| `Send-WakeOnLan` | `wake-on-lan.conf` | [Send-WakeOnLan](Send-WakeOnLan.md) |
| `Set-DisplayLanguage` | `language.conf` | [Set-DisplayLanguage](Set-DisplayLanguage.md) |
| `Set-KeyboardLayouts` | `language.conf` | [Set-KeyboardLayouts](Set-KeyboardLayouts.md) |
| `Set-Locale` | `language.conf` | [Set-Locale](Set-Locale.md) |
| `Set-SpecialFolders` | `special-folders.conf` | [Set-SpecialFolders](Set-SpecialFolders.md) |
| `Set-SystemTheme` | `theme.conf` | [Set-SystemTheme](Set-SystemTheme.md) |
| `Set-Wallpaper` | `wallpapers.conf` | [Set-Wallpaper](Set-Wallpaper.md) |
| `Test-MachineOnline` | `wake-on-lan.conf` | [Test-MachineOnline](Test-MachineOnline.md) |

## Commands With No Configuration

[Get-InstalledApps](Get-InstalledApps.md), [List-Drives](List-Drives.md),
[Measure-ShellStartup](Measure-ShellStartup.md), [Restart-Machine](Restart-Machine.md),
[Terminate-WindowsTerminalTabs](Terminate-WindowsTerminalTabs.md),
[Update-DirectoryNames](Update-DirectoryNames.md), [Upgrade-All](Upgrade-All.md)

## Related

- [All configuration guides](../README.md)
- [Configuration](../../configuration.md)
