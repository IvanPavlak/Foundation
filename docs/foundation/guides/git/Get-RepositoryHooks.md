# Get-RepositoryHooks

Lists the repositories `repositories.conf` marks to use their tracked git hooks (`hooks=FOLDER`) and the `core.hooksPath` each clone has, so a clone where the setting is missing is seen, not assumed.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`repositories.conf`](../../configuration.md#repositoriesconf) | `NAME PATH-OR-URL DIR [archive=FOLDER] hooks=FOLDER [shallow]` | no line carries `hooks=` | A repository that is listed: FOLDER is the hooks folder inside it, relative to its root, and DIR the clone that is checked. A line without the word is never listed |
| [`repositories.conf`](../../configuration.md#repositoriesconf) | `[Group]` | `[Private]` | Every group is read; a folder two lines share is listed once |
| [`repositories.conf`](../../configuration.md#repositoriesconf) | `base URL` | `https://github.com` | The prefix of a relative path, for the name a repository is listed under (the name of its URL) |

## Decisions

1. Which repositories track their git hooks in a folder of their own?
    - Options: add `hooks=FOLDER` to their line, after DIR, before or after `archive=FOLDER` and before `shallow` (`hooks=.githooks`). Update-Repositories and Initialize-Repository then set `core.hooksPath` of each clone; this command only reports. Mark only repositories whose hooks you have read: a hook is code that runs on your machine at every commit.
    - Default: no repository is marked, so nothing is listed and no clone is touched.
    - More detail: [`repositories.conf`](../../configuration.md#repositoriesconf)

## Where to Put Values

`Unix/config/repositories.local.conf`: a `[Group]` there replaces the base group of the same name whole, so the `hooks=FOLDER` word goes on the overlay's own repository line. `@TYPE` limits a line to machine types.

## Steps Overview

1. Mark the repository
2. Set the hooks path
3. Check what each clone has

## Step 1: Mark the repository

```conf
[Private]
MyRepo   /MyUser/MyRepo.git   $DEV/MyRepo   hooks=.githooks
```

## Step 2: Set the hooks path

```bash
Update-Repositories MyRepo
```

It clones or updates the repository and sets `core.hooksPath` of the clone to `.githooks`. The regular update (Bootstrap's RepositoryUpdate step, the startup update) does the same on every machine.

## Step 3: Check what each clone has

```bash
Get-RepositoryHooks
```

| State | Meaning |
| ----- | ------- |
| `Active` | The clone's hooks path is the configured folder. `not executable: NAME` after it names hook files git skips; fix their mode in the repository (`git update-index --chmod=+x FOLDER/NAME`) |
| `NotSet`, `Different` | The clone has no hooks path, or another one; the next Update-Repositories sets it |
| `MissingFolder` | The folder is not in the clone: the checked-out branch has none, or the word is misspelled |
| `Invalid` | The folder is absolute or leaves the repository; write it relative to the repository root |
| `NotCloned`, `NotConfigured`, `NotARepository` | The folder is not on this machine, the line has none here, or it is not the top of a git repository |
| `Stale` | An earlier run set this clone's hooks path and its line lost the word; the next Update-Repositories of that repository removes the value it set |

## Verification

```bash
Get-RepositoryHooks
Test-ConfigurationSchema --quiet
cat Unix/config/repositories.local.conf
```

## Complete Example

`Unix/config/repositories.local.conf`:

```conf
base https://MyUser@github.com

[Private]
Dotfiles   /MyUser/Dotfiles.git   $DOTFILES_ROOT
MyRepo     /MyUser/MyRepo.git     $DEV/MyRepo     archive=Projects/Tools   hooks=.githooks
MyNotes    /MyUser/MyNotes.git    $DEV/MyNotes    shallow
```

Then `Get-RepositoryHooks` lists `[MyRepo] configured [.githooks], found [.githooks] - Active` once `Update-Repositories MyRepo` ran; `MyNotes` and `Dotfiles` are not listed and their clones are never touched.

## Related

- [`Get-RepositoryHooks` in the Git module reference](../../modules/Git.md#get-repositoryhooks)
- [Update-Repositories](Update-Repositories.md)
- [Git configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
