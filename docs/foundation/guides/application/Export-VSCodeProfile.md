# Export-VSCodeProfile

Captures the live VS Code profile a `vscode-profiles.conf` catalogue entry deploys onto back into
its repository folder (settings, keybindings, tasks, snippets and `extensions.txt`); nothing in
VS Code changes.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`vscode-profiles.conf`](../../configuration.md#files) | `profile NAME [TARGET]` | none, the catalogue is empty | The entry `NAME` to export, and the VS Code profile `TARGET` it is read from (default `NAME`; `Default` is VS Code's built-in profile) |
| [`vscode-profiles.conf`](../../configuration.md#files) | `root PATH` | `$DOTFILES_ROOT/VSCode/Profiles` | Where the entry's folder is created and written |
| [`vscode-profiles.conf`](../../configuration.md#files) | `user-data PATH` | `~/Library/Application Support/Code/User` | VS Code's user data folder, where the live profile is looked up |

## Decisions

1. Which live VS Code profile should become a repository profile, and under what name?
    - Options: a `profile NAME [TARGET]` line; `TARGET` is the VS Code profile to read when it differs from the folder name. The profile must already exist in VS Code: export never registers one.
    - Default: no entries, so every name is refused with "add it there first".
    - More detail: [`vscode-profiles.conf`](../../configuration.md#files)
2. Where do the profile folders live?
    - Options: `root PATH`; `~`, `$DEV` and `$DOTFILES_ROOT` expand.
    - Default: `$DOTFILES_ROOT/VSCode/Profiles`.
    - More detail: [`vscode-profiles.conf`](../../configuration.md#files)
3. Is VS Code's user data folder somewhere other than the default?
    - Options: `user-data PATH`.
    - Default: `~/Library/Application Support/Code/User`.
    - More detail: [`vscode-profiles.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/vscode-profiles.local.conf`, created when missing. The file has no sections: its lines
are added after the base ones, the last `root` and `user-data` line for this machine type wins,
and a later `profile` line for the same name changes that entry's target. The same file drives
[Deploy-VSCodeProfiles](Deploy-VSCodeProfiles.md).

## Steps Overview

1. Add the catalogue entry
2. Check the configuration

## Step 1: Add the catalogue entry

```conf
profile MyProject
profile Base Default
```

## Step 2: Check the configuration

```bash
Deploy-VSCodeProfiles --check MyProject
```

A name outside the catalogue is reported as an error; an entry without a folder yet is reported
as skipped, which is what `Export-VSCodeProfile MyProject` then creates. Review what an export
wrote with `git diff` before committing it.

## Verification

```bash
cat Unix/config/vscode-profiles.local.conf
Deploy-VSCodeProfiles --check MyProject
git diff --stat -- VSCode/Profiles
```

## Complete Example

`Unix/config/vscode-profiles.local.conf`:

```conf
root $DOTFILES_ROOT/VSCode/Profiles
user-data ~/Library/Application Support/Code/User
profile Base Default
profile MyProject
```

## Related

- [`Export-VSCodeProfile` in the Application module reference](../../modules/Application.md#export-vscodeprofile)
- [Deploy-VSCodeProfiles](Deploy-VSCodeProfiles.md)
- [Application configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
