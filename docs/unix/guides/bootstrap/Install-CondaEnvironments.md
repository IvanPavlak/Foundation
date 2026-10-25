# Install-CondaEnvironments

Creates the Conda environments of `conda-environments.conf` from their `.yml` files, leaving the
ones that already exist alone.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`conda-environments.conf`](../../configuration.md#dotnetconf-and-conda-environmentsconf) | `directory PATH` | `Conda/Environments/macOS` | The folder of the environment files; a relative path starts at the repository root |
| [`conda-environments.conf`](../../configuration.md#dotnetconf-and-conda-environmentsconf) | `env NAME` | none: every `.yml` file in the folder | An environment to create from `NAME.yml` in that folder, named after the file |
| [`conda-environments.conf`](../../configuration.md#dotnetconf-and-conda-environmentsconf) | `update-base on\|off` | `off` | Whether conda in the base environment is updated from the defaults channel first |

## Decisions

1. Where are the environment files?
    - Options: a folder of `.yml` exports built for macOS (`osx-arm64` or `noarch`, `conda-forge`), relative to the repository root or absolute (`$DEV/MyRepo/environments`).
    - Default: `Conda/Environments/macOS`; a folder that does not exist makes the command warn and do nothing.
    - More detail: [`conda-environments.conf`](../../configuration.md#dotnetconf-and-conda-environmentsconf)
2. Which environments should be created?
    - Options: one `env NAME` line per environment (`env MyEnvironment` creates it from `MyEnvironment.yml`), per machine type with `@TYPE`.
    - Default: without `env` lines, every `.yml` file in the folder.
    - More detail: [`conda-environments.conf`](../../configuration.md#dotnetconf-and-conda-environmentsconf)
3. Should conda itself be updated first?
    - Options: `update-base on` or `update-base off`. On needs the Terms of Service of the defaults channel accepted once (`conda tos accept`).
    - Default: off.
    - More detail: [`conda-environments.conf`](../../configuration.md#dotnetconf-and-conda-environmentsconf)

## Where to Put Values

`Unix/config/conda-environments.local.conf`, created when missing. Its lines are read after the
base ones: its `directory` and `update-base` win (the last line counts), its `env` lines are added
to the base ones, and `-LINE` takes a base line back. `@TYPE` limits a line to one machine type.

## Steps Overview

1. Name the folder and the environments
2. Check the configuration

## Step 1: Name the folder and the environments

```conf
directory Conda/Environments/macOS
env MyEnvironment
update-base off
```

A name without a file in the folder is skipped with a warning; an environment `conda env list`
already shows is left alone.

## Step 2: Check the configuration

```bash
Install-CondaEnvironments --list
```

It lists each environment with `exists`, `missing` or `no file`, and changes nothing.

## Verification

```bash
Install-CondaEnvironments --list
Install-CondaEnvironments --dry-run
Bootstrap --only CondaEnvironments --dry-run
Test-ConfigurationSchema --quiet
```

## Complete Example

`Unix/config/conda-environments.local.conf`:

```conf
directory Conda/Environments/macOS
env MyEnvironment
@Work env MyWorkEnvironment
update-base off
```

## Related

- [`Install-CondaEnvironments` in the Bootstrap module reference](../../modules/Bootstrap.md#install-condaenvironments)
- [Bootstrap configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
