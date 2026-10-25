# Invoke-StartupRepositoryUpdate

Updates the repositories of `startup-scope` from the shell once a day (or once per interval),
never cloning, when `repositories.conf` says `startup on`.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`repositories.conf`](../../configuration.md#repositoriesconf) | `startup on\|off` | off (no line) | Whether the shell runs the update at all; `--force` runs it regardless |
| [`repositories.conf`](../../configuration.md#repositoriesconf) | `startup-schedule daily\|interval` | `daily` | `daily`: once a day, the first shell after the day starts or the first prompt after it in a shell already open; `interval`: at most once per `startup-interval-hours`, checked when a shell starts. Any other value is `daily` |
| [`repositories.conf`](../../configuration.md#repositoriesconf) | `startup-day-start-hour N` | `6` | The hour (0-23) a new day starts on the daily schedule; anything else (24 and up, a non-number) is 6, without a warning, as on Windows |
| [`repositories.conf`](../../configuration.md#repositoriesconf) | `startup-interval-hours N` | `24` | The interval schedule's minimum gap, in whole hours; anything else (a fraction, a non-number) is 24, without a warning |
| [`repositories.conf`](../../configuration.md#repositoriesconf) | `startup-scope All\|GROUP...` | none: the `repository-scope` of `bootstrap.conf`, then `All` | What it updates: every group, or the groups given, through `Update-Repositories --no-clone --quiet`. Group names only, as on Windows: a name that is no group (a repository name included) is reported and nothing is updated |
| [`bootstrap.conf`](../../configuration.md#bootstrapconf) | `repository-scope All\|GROUP...` | `All` | The scope when `repositories.conf` has no `startup-scope` line for this machine type (the Windows fallback to `BootstrapConfig.RepositoryUpdateScope`), so the shell updates what Bootstrap does; same rules |
| [`repositories.conf`](../../configuration.md#repositoriesconf) | `base`, `[Group]`, `NAME PATH-OR-URL [DIR]`, `include-default-branch`, `default-branch` | see [Update-Repositories](Update-Repositories.md) | The repositories and how each is updated |

## Decisions

1. Should the shell update the repositories on its own?
    - Options: `startup on`; `startup off` (or no line) leaves it to `Update-Repositories` by hand. `FOUNDATION_STARTUP_SKIP=RepositoryUpdate` in the environment skips it in one shell.
    - Default: off.
    - More detail: [`repositories.conf`](../../configuration.md#repositoriesconf)
2. How often should it run?
    - Options: `startup-schedule daily` with `startup-day-start-hour N` (a shell opened past midnight still counts as the day before until that hour); `startup-schedule interval` with `startup-interval-hours N`.
    - Default: daily, the day starting at 6.
    - More detail: [`repositories.conf`](../../configuration.md#repositoriesconf)
3. Which repositories should it update?
    - Options: `startup-scope All`, or group names (`startup-scope Private Work`), matched case-insensitively; `@TYPE startup-scope ...` lines give each machine type its own scope, the last line for this type winning. A repository name is not accepted: put the repositories to update in a group of their own.
    - Default: no line, so the `repository-scope` of `bootstrap.conf` for this machine type applies, and `All` without one. Missing repositories are never cloned; they are reported as skipped.
    - More detail: [`repositories.conf`](../../configuration.md#repositoriesconf)

## Where to Put Values

`Unix/config/repositories.local.conf`, created by hand when missing. Its lines before the first
section are added after the base ones, and for each setting the last line for this machine type
wins, so an overlay `startup-scope` replaces a base one (the base ships none, so Bootstrap's
`repository-scope` applies until you set one). `@TYPE` limits a line to machine
types; `-LINE` takes a base line back.

## Steps Overview

1. Turn the update on
2. Choose the schedule and scope
3. Check the configuration

## Step 1: Turn the update on

```conf
startup on
```

## Step 2: Choose the schedule and scope

```conf
startup-schedule daily
startup-day-start-hour 6
startup-scope All
@Work startup-scope Private Work
```

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `@TYPE` prefix that is not a machine type. A scope name that is not a group is
reported when the update runs (`Unknown repository group [...]`), and then nothing is updated.

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n 'startup' Unix/config/repositories.local.conf
cat Unix/logs/.next-repository-update
```

The last file holds `EPOCH SCHEDULE`, when the next run is due (0 when due now).

## Complete Example

`Unix/config/repositories.local.conf`:

```conf
base https://MyUser@github.com
include-default-branch on
startup on
startup-schedule daily
startup-day-start-hour 6
startup-scope All
@Laptop startup-scope Private
@Test startup off

[Private]
Dotfiles   /MyUser/Dotfiles.git   $DOTFILES_ROOT
MyRepo     /MyUser/MyRepo.git     $DEV/MyRepo

[Work]
@Work MyWorkRepo   https://git.example.com/MyTeam/MyWorkRepo.git   $DEV/MyWorkRepo
```

## Related

- [`Invoke-StartupRepositoryUpdate` in the Git module reference](../../modules/Git.md#invoke-startuprepositoryupdate)
- [Git configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
