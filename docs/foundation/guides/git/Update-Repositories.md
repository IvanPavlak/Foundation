# Update-Repositories

Clones the missing repositories of `repositories.conf` and updates the existing ones without ever
losing local work, by group, by repository name, `--all`, from a menu or for one URL and folder
outside the file (`--repository-url URL --local-path DIR`). The configured folder
(`DIR`) is used except with `--archive` (history-less copies on the Desktop) and
`--in-current-directory` (everything in `./<name>`), as on Windows.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`repositories.conf`](../../configuration.md#repositoriesconf) | `base URL` | `https://github.com` | The prefix of every relative repository path; the last `base` line wins, so the overlay's replaces the base one |
| [`repositories.conf`](../../configuration.md#repositoriesconf) | `[Group]` | `[Private]` | A repository group: a menu entry and `Update-Repositories GROUP`; `--all` runs every group |
| [`repositories.conf`](../../configuration.md#repositoriesconf) | `NAME PATH-OR-URL [DIR] [shallow]` | the repository itself, in `$DOTFILES_ROOT` | One repository: a path under `base` (`/MyUser/MyRepo.git`) or a full URL (`http(s)://`, `git@`, `ssh://`, `git://`, `file://`), cloned into DIR when missing and updated otherwise; a line without DIR is skipped as having no local path on this machine; `shallow` clones it `--depth 1`, keeping its `.git` |
| [`repositories.conf`](../../configuration.md#repositoriesconf) | `include-default-branch on\|off` | off | Also fast-forward each default branch while another branch is checked out; `--include-default-branch` and `--no-include-default-branch` override it for one run |
| [`repositories.conf`](../../configuration.md#repositoriesconf) | `default-branch NAME` | unset: each repository's `origin/HEAD` | The default branch of every repository, for `include-default-branch` |

## Decisions

1. Where do your repositories live?
    - Options: `base URL` for the host the relative paths are under (`https://MyUser@github.com` to name the account git's credential helper uses); a full URL on a repository line ignores it.
    - Default: `https://github.com`.
    - More detail: [`repositories.conf`](../../configuration.md#repositoriesconf)
2. How should the repositories be grouped?
    - Options: one `[Group]` per set you update together (`[Private]`, `[Work]`); a repository may appear in several groups and still runs once per call (once per folder: two entries that only share a name both run). `Update-Repositories NAME` matches a group first, then a repository; `--group NAME` takes groups only (an unknown one stops the call before anything runs) and `--repositories NAME` repositories only.
    - Default: `[Private]` with the repository itself; an overlay `[Private]` replaces it whole, so keep that line.
    - More detail: [`repositories.conf`](../../configuration.md#repositoriesconf)
3. Where does each repository go on this machine?
    - Options: a DIR per line (`$DEV/MyRepo`, `~/Code/MyRepo`); `@TYPE` lines give a machine type its own folder or leave a repository out there.
    - Default: a line without DIR is reported as not configured and skipped.
    - More detail: [Shared format](../../configuration.md#shared-format)
4. Which repositories should be cloned without their history?
    - Options: end the line in `shallow` for a repository with a large history (an Obsidian vault); it is cloned `--depth 1` and can still commit and push. Initialize-Repository reads the same word for the same URL.
    - Default: full history.
    - More detail: [`repositories.conf`](../../configuration.md#repositoriesconf)
5. Should the default branch be fast-forwarded too?
    - Options: `include-default-branch on` (`git fetch origin <default>:<default>`, never touching the working tree; one with local commits is left alone); `default-branch NAME` when every repository's default is the same and `origin/HEAD` is not set.
    - Default: off.
    - More detail: [`repositories.conf`](../../configuration.md#repositoriesconf)

## Where to Put Values

`Unix/config/repositories.local.conf`, created by hand when missing. Its lines before the first
section are added after the base ones (the last `base`, `include-default-branch` and
`default-branch` line for this machine type wins); a `[Group]` replaces a base group of the same
name whole; `-LINE` takes a base top-level line back. `@TYPE` limits any line to machine types.

## Steps Overview

1. Set the base and the default-branch behavior
2. Add the groups
3. Check the configuration

## Step 1: Set the base and the default-branch behavior

```conf
base https://MyUser@github.com
include-default-branch on
```

## Step 2: Add the groups

```conf
[Private]
Dotfiles   /MyUser/Dotfiles.git   $DOTFILES_ROOT
MyRepo     /MyUser/MyRepo.git     $DEV/MyRepo

[Work]
@Work MyWorkRepo   https://git.example.com/MyTeam/MyWorkRepo.git   $DEV/MyWorkRepo
```

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `@TYPE` prefix that is not a machine type. Test-ConfigurationSchema does not check
the repository lines themselves: a run that cannot reach a URL or a folder reports that
repository as needing attention.

## Verification

```bash
Test-ConfigurationSchema --quiet
cat Unix/config/repositories.local.conf
```

## Complete Example

`Unix/config/repositories.local.conf`:

```conf
base https://MyUser@github.com
include-default-branch on
default-branch master

[Private]
Dotfiles   /MyUser/Dotfiles.git   $DOTFILES_ROOT
MyRepo     /MyUser/MyRepo.git     $DEV/MyRepo
@Laptop MyNotes   /MyUser/MyNotes.git   ~/Documents/MyNotes   shallow

[Work]
@Work MyWorkRepo   https://git.example.com/MyTeam/MyWorkRepo.git   $DEV/MyWorkRepo
```

## Related

- [`Update-Repositories` in the Git module reference](../../modules/Git.md#update-repositories)
- [Git configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
