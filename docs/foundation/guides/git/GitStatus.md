# GitStatus

`git status` with the configured arguments (alias `gs`): `--short` unless `git.conf` sets others,
and arguments given on the call replace the configured ones.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`git.conf`](../../configuration.md#gitconf) | `status-arguments ARG...` | none: `--short` | What `gs` passes to `git status` when called without arguments (the Windows `GitStatusArguments`); a bare `status-arguments` line runs a plain `git status`; the last line for this machine type wins |

## Decisions

1. What should a bare `gs` show?
    - Options: `status-arguments --short` (one line per file), `status-arguments -v -v -u` (the staged and unstaged diffs and every untracked file), a bare `status-arguments` (git's long format), or any other `git status` arguments; `@TYPE` lines give a machine type its own.
    - Default: `--short`, the WinuX base. Arguments on the call (`gs -v -v -u`) always replace the configured ones for that call.
    - More detail: [`git.conf`](../../configuration.md#gitconf)

## Where to Put Values

`Unix/config/git.local.conf`, the file that already holds the git identity (Initialize-Configuration
creates it). Its lines are added after the base ones, so the last `status-arguments` line for this
machine type wins; `@TYPE` limits a line to machine types.

## Steps Overview

1. Add the `status-arguments` line
2. Check the configuration

## Step 1: Add the `status-arguments` line

```conf
status-arguments -v -v -u
```

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `@TYPE` prefix that is not a machine type.

## Verification

```bash
Test-ConfigurationSchema --quiet
cat Unix/config/git.local.conf
```

## Complete Example

`Unix/config/git.local.conf`:

```conf
name My Name
email you@example.com
status-arguments --short
@Work status-arguments -v -v -u
```

## Related

- [`GitStatus` in the Git module reference](../../modules/Git.md#gitstatus)
- [Git configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
