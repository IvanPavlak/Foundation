# Determine-DotnetDependencies

Reports which .NET SDKs the projects under a search folder target and which of them this Mac is
missing, with the Homebrew line that installs each.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`dotnet.conf`](../../configuration.md#dotnetconf-and-conda-environmentsconf) | `projects-search-path PATH` | none, so the dev root `$DEV` | The folder searched for `*.csproj`, `*.fsproj` and `*.vbproj` when no SEARCH-PATH is given; the DotnetProjectsSearchPath of Windows |

The other lines of `dotnet.conf` (`ef-version`, `nuget-template`, `nuget-config`) belong to
Install-DotnetEf and Configure-NuGetConfig; this command does not read them.

## Decisions

1. Where should Determine-DotnetDependencies look for .NET projects by default?
    - Options: one `projects-search-path PATH` line; `PATH` takes `~`, `$DEV` and `$DOTFILES_ROOT` (`$DEV`, `$DEV/MyProject`, `~/Source`). The last line for this machine type wins, so `@Work projects-search-path ...` gives one machine type its own folder. A SEARCH-PATH argument beats the line for one run.
    - Default: no line, so the dev root `$DEV` (the `dev-root` of `machines.conf`, else the folder holding this clone). A path that does not exist stops the run.
    - More detail: [`dotnet.conf`](../../configuration.md#dotnetconf-and-conda-environmentsconf)

## Where to Put Values

`Unix/config/dotnet.local.conf`, created when missing. `dotnet.conf` has no sections: the
overlay's lines are added after the base lines and the last `projects-search-path` line wins. A
line may start with `@TYPE` to apply on one machine type only.

## Steps Overview

1. Add the `projects-search-path` line
2. Check the configuration

## Step 1: Add the `projects-search-path` line

The folder the search starts in; every project file below it counts, except paths through
`node_modules`, `bin`, `obj`, `.git`, `.vs` or `packages` (`--exclude` replaces that list for one
run).

```conf
projects-search-path $DEV
@Work projects-search-path $DEV/MyProject
```

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `@TYPE` prefix that names a machine type `machines.conf` does not have.

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n 'projects-search-path' Unix/config/dotnet.local.conf
Determine-DotnetDependencies --list-projects
```

The run only reads: its first line names the search path it used.

## Complete Example

`Unix/config/dotnet.local.conf`:

```conf
projects-search-path $DEV
@Work projects-search-path $DEV/MyProject
```

## Related

- [`Determine-DotnetDependencies` in the System module reference](../../modules/System.md#determine-dotnetdependencies)
- [System configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
