# Initialize-Configuration

Writes what makes a generic clone this user's Mac into the `.local` overlays - the git identity,
this Mac's `host` line and its machine type's dev root - asking only for what is not set yet.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`git.conf`](../../configuration.md#files) | `name NAME` | none | The git `user.name`; the GitIdentity step sets the global one from it |
| [`git.conf`](../../configuration.md#files) | `email ADDRESS` | none | The git `user.email`; the GitIdentity step sets the global one from it |
| [`machines.conf`](../../configuration.md#files) | `type NAME` | `type Test` | The machine types offered for this Mac; any other answer is refused |
| [`machines.conf`](../../configuration.md#files) | `host HOSTNAME TYPE` | none | This Mac's name and machine type; RenameMachine applies a new name |
| [`machines.conf`](../../configuration.md#files) | `@TYPE dev-root PATH` | none: the folder that holds this clone | The dev root of a machine type, named `$DEV` in every configured path |

## Decisions

1. Which git identity should commits on this Mac carry?
    - Options: a name and an email (`--git-name`, `--git-email`, `FOUNDATION_GIT_NAME`, `FOUNDATION_GIT_EMAIL`, or the prompt); written as `name` and `email` lines.
    - Default: none; an identity already in `git.local.conf` or the global git config is kept and not asked for, and an unanswered one is left out with a warning.
    - More detail: [`git.conf`](../../configuration.md#files)
2. What is this Mac called?
    - Options: one word, as `LocalHostName` has it (`My-Mac`); `--machine-name` or the prompt.
    - Default: the current name; a different one is applied by the RenameMachine step.
    - More detail: [Machine type](../../README.md#machine-type)
3. Which machine type is this Mac?
    - Options: one of the `type` lines of `machines.conf`; add the type there first (`type Laptop`) when it is new. `--machine-type` or the prompt.
    - Default: the type chezmoi asked on the first run, else the detected one (the `default` line, else `Test`).
    - More detail: [`machines.conf`](../../configuration.md#files)
4. Where do this machine type's repositories live?
    - Options: a folder (`~/Development/GitHub`), `--dev-root`, `FOUNDATION_DEV_ROOT` or the prompt; written with `~` for the home folder.
    - Default: the folder that holds this clone.
    - More detail: [Shared format](../../configuration.md#shared-format)

## Where to Put Values

The command writes them itself: `Unix/config/git.local.conf` and
`Unix/config/machines.local.conf`, each created with a header when missing and backed up into
`Backups/Unix/Config/` before it changes. Lines before the first section are added to the base
ones, and the last `dev-root` for this machine type wins. Writing the lines by hand is equally
valid; the command then finds them set and asks nothing.

## Steps Overview

1. Declare the machine types
2. Write the identity, host and dev root
3. Check the configuration

## Step 1: Declare the machine types

A fork's `Unix/config/machines.local.conf` lists every type it uses (here Laptop and Work), so the type answer is accepted:

```conf
type Laptop
type Work
```

## Step 2: Write the identity, host and dev root

Run `Initialize-Configuration` (or let `Bootstrap --with-initial-setup` run it first), answering
the prompts, or pass the values as flags. It writes lines such as:

```conf
name Your Name
email you@example.com
```

```conf
host My-Mac Laptop
@Laptop dev-root ~/Development/GitHub
```

A value already set is not asked again; `--force` asks and writes everything again, replacing
those lines. `--machine-name` or `--machine-type` replaces the host line and `--dev-root` (or
`FOUNDATION_DEV_ROOT`) the dev-root line even without `--force`; an existing git identity is only
replaced with `--force`, and `--git-name` or `--git-email` given without it is ignored.

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports a `host`, `default` or `@TYPE` naming a type that has no `type` line, and a dev root
that is not a folder.

## Verification

```bash
Initialize-Configuration --dry-run
Test-ConfigurationSchema --quiet
Bootstrap --only MachineType --dry-run
```

`--dry-run` asks nothing and says what is missing and would be written.

## Complete Example

`Unix/config/git.local.conf`:

```conf
name Your Name
email you@example.com
```

`Unix/config/machines.local.conf`:

```conf
type Laptop
type Work
host My-Mac Laptop
host My-Work-Mac Work
@Laptop dev-root ~/Development/GitHub
@Work dev-root ~/Development/Work
```

## Related

- [`Initialize-Configuration` in the Bootstrap module reference](../../modules/Bootstrap.md#initialize-configuration)
- [Bootstrap configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
