# Deploy-VSCodeProfiles

Links the repository's VS Code profile folders into VS Code, links the local extensions and
installs each profile's extensions, for the profiles `vscode-profiles.conf` selects for this
machine type.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`vscode-profiles.conf`](../../configuration.md#files) | `profile NAME [TARGET]` | none, the catalogue is empty | A catalogue entry: the folder `NAME` under `root`, deployed onto the VS Code profile `TARGET` (default `NAME`; `Default` is VS Code's built-in profile) |
| [`vscode-profiles.conf`](../../configuration.md#files) | `deploy NAME...` | none, so a run deploys nothing | The entries this machine deploys; the last line for this machine type wins |
| [`vscode-profiles.conf`](../../configuration.md#files) | `root PATH` | `$DOTFILES_ROOT/VSCode/Profiles` | Where the profile folders live (`settings.json`, `keybindings.json`, `keybindings.macos.json`, `tasks.json`, `snippets/`, `extensions.txt`) |
| [`vscode-profiles.conf`](../../configuration.md#files) | `extensions PATH` | `$DOTFILES_ROOT/VSCode/Extensions` | The local extensions linked into `~/.vscode/extensions`, one unpackaged folder with a `package.json` each |
| [`vscode-profiles.conf`](../../configuration.md#files) | `user-data PATH` | `~/Library/Application Support/Code/User` | VS Code's user data folder, the `Default` profile; other profiles live under its `profiles/` |
| [`vscode-profiles.conf`](../../configuration.md#files) | `settings-sync on\|off` | `off` | `off` installs extensions with `--do-not-sync`; `on` lets Settings Sync carry them |
| [`vscode-profiles.conf`](../../configuration.md#files) | `prune on\|off` | `off` | `on` uninstalls extensions `extensions.txt` does not name, as `--prune` does for one run |
| [`bootstrap.conf`](../../configuration.md#bootstrapconf) | `step VSCodeProfiles on\|off` | `off` | Whether Bootstrap runs this command as its opt-in VSCodeProfiles step |

## Decisions

1. Which VS Code profiles does the repository carry?
    - Options: one `profile NAME [TARGET]` line per folder under `root`; `TARGET` names the VS Code profile it lands on when that differs from `NAME` (`profile Base Default` deploys the `Base` folder onto VS Code's built-in profile). Capture a folder from a live profile with [Export-VSCodeProfile](Export-VSCodeProfile.md).
    - Default: no entries; a run only links the local extensions.
    - More detail: [`vscode-profiles.conf`](../../configuration.md#files)
2. Which of them does this machine deploy?
    - Options: a `deploy NAME...` line, untagged first and `@TYPE deploy NAME...` lines after it (the last line for this machine type wins); `Deploy-VSCodeProfiles NAME` deploys named entries for one run instead.
    - Default: nothing is selected, and the run says so.
    - More detail: [Shared format](../../configuration.md#shared-format)
3. Should Settings Sync carry the installed extensions?
    - Options: `settings-sync off` or `settings-sync on`.
    - Default: `off`, extensions install with `--do-not-sync`.
    - More detail: [`vscode-profiles.conf`](../../configuration.md#files)
4. Should extensions that `extensions.txt` does not list be uninstalled?
    - Options: `prune on` for every run, or `prune off` and `--prune` when you want it once. Linked local extensions are never pruned.
    - Default: `off`, extras stay installed.
    - More detail: [`vscode-profiles.conf`](../../configuration.md#files)
5. Do the profile folders, local extensions or VS Code's user data live somewhere other than the defaults?
    - Options: `root PATH`, `extensions PATH`, `user-data PATH`; `~`, `$DEV` and `$DOTFILES_ROOT` expand.
    - Default: `$DOTFILES_ROOT/VSCode/Profiles`, `$DOTFILES_ROOT/VSCode/Extensions`, `~/Library/Application Support/Code/User`.
    - More detail: [Shared format](../../configuration.md#shared-format)
6. Should Bootstrap deploy the profiles?
    - Options: `step VSCodeProfiles on` in `bootstrap.local.conf`, or leave it off and run the command by hand.
    - Default: off.
    - More detail: [`bootstrap.conf`](../../configuration.md#bootstrapconf)

## Where to Put Values

`Unix/config/vscode-profiles.local.conf`, created when missing. The file has no sections: its lines
are added after the base ones. For `root`, `extensions`, `user-data`, `settings-sync`, `prune` and
`deploy` the last line for this machine type wins, so an overlay line overrides the base. A later
`profile` line for the same name changes that entry's target. `@TYPE` limits a line to machine
types; `-LINE` takes a base line back. The Bootstrap switch goes in
`Unix/config/bootstrap.local.conf`, before its first section.

## Steps Overview

1. Add the catalogue entries
2. Select the entries for each machine type
3. Set the extension behaviour
4. Check the configuration

## Step 1: Add the catalogue entries

Each entry is a folder under `root`; create it with `Export-VSCodeProfile NAME` after adding the line.

```conf
profile Base Default
profile MyProject
```

## Step 2: Select the entries for each machine type

```conf
deploy Base
@Work deploy Base MyProject
```

## Step 3: Set the extension behaviour

```conf
settings-sync off
prune off
```

## Step 4: Check the configuration

```bash
Deploy-VSCodeProfiles --check
```

It lists every link, profile registration and extension a run would add (and, with `prune on`
or `--prune`, remove), and changes nothing. A name outside the catalogue is reported as an error;
an entry without a folder is skipped with a warning.

## Verification

```bash
Deploy-VSCodeProfiles --check
Deploy-VSCodeProfiles --check MyProject
cat Unix/config/vscode-profiles.local.conf
ls "$DOTFILES_ROOT/VSCode/Profiles"
```

## Complete Example

`Unix/config/vscode-profiles.local.conf`:

```conf
profile Base Default
profile MyProject
deploy Base
@Work deploy Base MyProject
settings-sync off
prune on
```

`Unix/config/bootstrap.local.conf`:

```conf
step VSCodeProfiles on
```

## Related

- [`Deploy-VSCodeProfiles` in the Application module reference](../../modules/Application.md#deploy-vscodeprofiles)
- [Export-VSCodeProfile](Export-VSCodeProfile.md)
- [Application configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
