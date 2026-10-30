# Bootstrap

Provisions this Mac in a fixed order of idempotent steps, each switched on or off per machine
type, and runs the inline steps (Packages, Spotlight, Firewall, SoftwareUpdate, PersonalSteps)
from the sections of `bootstrap.conf`.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`bootstrap.conf`](../../configuration.md#bootstrapconf) | `step NAME on\|off` | none: every step keeps its built-in default (`Bootstrap --list`) | Whether a step runs; before the first section, the last line for this machine type wins |
| [`bootstrap.conf`](../../configuration.md#bootstrapconf) | `repository-scope All\|GROUP...` | `All` | The `repositories.conf` groups the RepositoryUpdate step updates; space- or comma-separated. Group names only: a name that is no group (a repository's included) updates nothing and fails the step. Also the startup update's scope when `repositories.conf` has no `startup-scope` for this machine type |
| [`bootstrap.conf`](../../configuration.md#bootstrapconf) | `[Packages]` `trust TYPE NAME` | the AeroSpace cask tap | A third-party tap entry Homebrew must trust before `brew bundle` loads it (`brew trust --TYPE NAME`) |
| [`bootstrap.conf`](../../configuration.md#bootstrapconf) | `[Packages]` `brewfile PATH` | none: `Unix/Brewfile`, then `Unix/Brewfile.local` | The Brewfiles the Packages step bundles, in order; a relative path starts at the repository root |
| [`bootstrap.conf`](../../configuration.md#bootstrapconf) | `[Spotlight]` `index VOLUME on\|off` | `index / on` | Spotlight indexing per volume (`sudo mdutil -i`), applied by the Spotlight step |
| [`bootstrap.conf`](../../configuration.md#bootstrapconf) | `[Firewall]` `KEY on\|off` | `globalstate on`, `allowsigned on`, `allowsignedapp on` | The application firewall switches `globalstate`, `stealthmode`, `allowsigned`, `allowsignedapp`, applied by the Firewall step |
| [`bootstrap.conf`](../../configuration.md#bootstrapconf) | `[SoftwareUpdate]` `defaults DOMAIN KEY TYPE VALUE` | automatic update checks and downloads on | Machine-wide preferences written with `sudo defaults write` by the SoftwareUpdate step |
| [`bootstrap.conf`](../../configuration.md#bootstrapconf) | `[PersonalSteps]` `COMMAND [ARG...]` | none | A fork's own commands, run in order by the PersonalSteps step |
| [`git.conf`](../../configuration.md#files) | `name NAME`, `email ADDRESS` | none | The global git identity the GitIdentity step sets when it is unset (else from `Git/.gitconfig`); `Bootstrap --only GitIdentity` also replaces a set one that differs |
| [`machines.conf`](../../configuration.md#files) | `host HOSTNAME TYPE` | none | This Mac's machine type, reported by the MachineType step (a warning names the line to add when it is missing); it picks every `@TYPE` line of every file, `step` lines included; the one InitializeConfiguration records on a first run governs the steps after it |
| [`machines.conf`](../../configuration.md#files) | `type NAME` | `type Test` | The machine types an `@TYPE` prefix may name |
| [`obsidian.conf`](../../configuration.md#files) | `settings PATH` | none: the vault keeps its own `.obsidian` | The repository folder the vault's `.obsidian` links to (hotkeys, plugins, saved workspaces), relative to the repository root or absolute; the ObsidianSettings step makes the link, backing up a real folder first |
| [`obsidian.conf`](../../configuration.md#files) | `directory PATH` | `~/Documents/Obsidian` | The vault folder the ObsidianSettings step links into (`OBSIDIAN_DIRECTORY` wins); a vault not cloned yet is skipped with a warning |
| [`language.conf`](../../configuration.md#files) | `default-locale NAME`, `default-display-language NAME`, `default-keyboard-set NAME` | none | What the Locale, DisplayLanguage and KeyboardLayouts steps apply; without a line the step does nothing |

## Decisions

1. Which steps should run on this Mac?
    - Options: a `step NAME on` or `step NAME off` line per step to change, before the first section; `Bootstrap --list` names every step with its default.
    - Default: the built-in default of each step (on when idempotent or empty-safe, off when it acts at once, prompts or needs root); InitializeConfiguration, RenameMachine and Permissions run only with `--with-initial-setup` (or when `--only` names them), whatever their `step` line says.
    - More detail: [Bootstrap a Mac](../../bootstrap.md#choosing-steps)
2. Should a step differ per machine type?
    - Options: an `@TYPE` prefix on the `step` line (`@Laptop step Power on`); the last line that applies wins.
    - Default: a line without a prefix applies on every machine type.
    - More detail: [Shared format](../../configuration.md#shared-format)
3. Which repositories should the RepositoryUpdate step update (once it is on)?
    - Options: `repository-scope All`, or the names of `repositories.conf` groups (`repository-scope Private Work`), per machine type with `@TYPE`. A repository name is not accepted: put the repositories to update in a group of their own.
    - Default: `All`, every repository.
    - More detail: [`bootstrap.conf`](../../configuration.md#bootstrapconf)
4. Which third-party taps must Homebrew trust, and which Brewfiles should the Packages step bundle?
    - Options: `trust TYPE NAME` lines (`trust cask some-org/tap/some-app`) and `brewfile PATH` lines in `[Packages]`.
    - Default: the AeroSpace tap is trusted; `Unix/Brewfile`, then `Unix/Brewfile.local` when it exists.
    - More detail: [`bootstrap.conf`](../../configuration.md#bootstrapconf)
5. Which volumes should Spotlight index, and which firewall switches should be set?
    - Options: `index VOLUME on|off` lines in `[Spotlight]`; `globalstate`, `stealthmode`, `allowsigned`, `allowsignedapp` with `on` or `off` in `[Firewall]`. Both steps need root and are off until turned on.
    - Default: `index / on`; firewall on and signed software allowed, stealth mode left as it is.
    - More detail: [`bootstrap.conf`](../../configuration.md#bootstrapconf)
6. Which machine-wide software update preferences should be written?
    - Options: `defaults DOMAIN KEY TYPE VALUE` lines in `[SoftwareUpdate]` (the step is off until turned on, and needs root).
    - Default: automatic checks and automatic downloads on.
    - More detail: [`bootstrap.conf`](../../configuration.md#bootstrapconf)
7. Does your fork have steps of its own?
    - Options: one `COMMAND [ARG...]` line per step in `[PersonalSteps]`: a Foundation command or any command on PATH, split into words with no shell (no quoting, pipes or `&&`); `@TYPE` limits a line to a machine type.
    - Default: none; the PersonalSteps step warns that nothing is configured.
    - More detail: [`bootstrap.conf`](../../configuration.md#bootstrapconf)
8. Which git identity should the GitIdentity step restore, and which machine type is this Mac?
    - Options: `name` and `email` in `git.local.conf`, a `host` line in `machines.local.conf`; Initialize-Configuration, the first step of `Bootstrap --with-initial-setup`, asks for them and writes them.
    - Default: no identity (the step falls back to `Git/.gitconfig`, else warns); an unlisted host gets the `default` machine type. After changing `name` or `email`, `Bootstrap --only GitIdentity` replaces the global identity with it (the full run only fills an unset one).
    - More detail: [Initialize-Configuration](Initialize-Configuration.md)
9. Which locale, display language and keyboard set should the language steps apply?
    - Options: `default-locale`, `default-display-language` and `default-keyboard-set` lines in `language.conf`, each naming one of its entries.
    - Default: none; the three steps do nothing.
    - More detail: [`language.conf`](../../configuration.md#files)
10. Should the Obsidian vault's `.obsidian` settings come from this repository?
    - Options: a `settings PATH` line in `obsidian.local.conf` naming the repository folder (`settings Obsidian/.obsidian`), next to the vault's `directory` line; no line keeps the vault's own settings.
    - Default: none; the ObsidianSettings step does nothing.
    - More detail: [`obsidian.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/bootstrap.local.conf`, created when missing. Its `step` and `repository-scope` lines
go before the first section; they are added after the base lines, so the last line for this
machine type wins, and `-LINE` takes a base line back. A `[Section]` there replaces the base
section whole, so copy every line you keep; an empty section turns that step's values off. Any
line takes `@TYPE`. The identity goes in `git.local.conf`, the host in `machines.local.conf`, the
language defaults in `language.local.conf`, the vault and its settings folder in
`obsidian.local.conf`.

The steps that run a command read that command's own file; their pages hold those values:
[Set-SystemDefaults](Set-SystemDefaults.md) (SystemDefaults), [Set-PowerSettings](Set-PowerSettings.md)
(Power), [Set-DockPins](Set-DockPins.md) (DockPins), [Set-LoginItems](Set-LoginItems.md)
(LoginItems), [Deploy-FirefoxProfile](Deploy-FirefoxProfile.md) (FirefoxProfile),
[Install-DotnetEf](Install-DotnetEf.md) (DotnetEf),
[Install-CondaEnvironments](Install-CondaEnvironments.md) (CondaEnvironments),
[Configure-NuGetConfig](Configure-NuGetConfig.md) (NuGetConfig),
[Configure-NpmConfig](Configure-NpmConfig.md) (NpmConfig),
[Configure-DockerDesktop](Configure-DockerDesktop.md) (DockerDesktop) and
[Initialize-Configuration](Initialize-Configuration.md) (InitializeConfiguration).

## Steps Overview

1. Choose the steps
2. Set the repository scope
3. Fill in the inline step sections
4. Add personal steps
5. Check the configuration

## Step 1: Choose the steps

`Bootstrap --list` prints every step with its default and its state for this run. Turn steps on
or off before the first section of `bootstrap.local.conf`, per machine type where they differ:

```conf
step Power on
step UpgradeAll on
step FirefoxProfile on
@Laptop step Rosetta on
@Work step NuGetConfig on
```

`--include`, `--skip` and `--only` change one run without touching the file.

## Step 2: Set the repository scope

Turn the RepositoryUpdate step on and name the `repositories.conf` groups it updates:

```conf
step RepositoryUpdate on
repository-scope All
@Laptop repository-scope Private Work
```

A name that is no group (a repository's included) is reported with the configured groups and
nothing is updated. Without a `startup-scope` of its own in `repositories.conf`, the automatic
update (Invoke-StartupRepositoryUpdate) uses this scope too.

## Step 3: Fill in the inline step sections

Only the sections you change; each replaces the base one whole.

```conf
[Packages]
trust cask some-org/tap/some-app
brewfile Unix/Brewfile
brewfile Unix/Brewfile.local

[Firewall]
globalstate on
stealthmode on
allowsigned on
allowsignedapp on
```

`[Spotlight]` takes `index VOLUME on|off`, `[SoftwareUpdate]` `defaults DOMAIN KEY TYPE VALUE`
lines; the Spotlight, Firewall and SoftwareUpdate steps are off until a `step` line turns them on.

## Step 4: Add personal steps

```conf
[PersonalSteps]
Set-DockPins
@Work Install-DotnetEf
my-setup-script --quiet
```

An unknown command is skipped with a warning; a failing line fails the step without stopping the
others.

## Step 5: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `@TYPE` prefix that names no `type` line of `machines.conf`. `Bootstrap --list`
rejects nothing in the file, so read its RUNS column to confirm the `step` lines took effect.

## Verification

```bash
Bootstrap --list
Bootstrap --dry-run
Bootstrap --only Packages,Firewall --dry-run
Test-ConfigurationSchema --quiet
```

`--dry-run` passes each command its own dry run, prints the inline commands, never asks for the
password and changes nothing. A real run exits 1 when a step failed, and also when a refused
administrator password skipped the *sudo* steps, even with no failed step.

## Complete Example

`Unix/config/bootstrap.local.conf`:

```conf
step Power on
step FirefoxProfile on
step Firewall on
step RepositoryUpdate on
@Laptop step Rosetta on
repository-scope All
@Laptop repository-scope Private Work

[Packages]
trust cask some-org/tap/some-app

[Spotlight]
index / on

[Firewall]
globalstate on
stealthmode on

[SoftwareUpdate]
defaults /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool true

[PersonalSteps]
Set-DockPins
@Work Install-DotnetEf
```

`Unix/config/git.local.conf`:

```conf
name Your Name
email you@example.com
```

`Unix/config/machines.local.conf`:

```conf
type Laptop
host My-Mac Laptop
```

`Unix/config/language.local.conf` (the names are entries of the same file):

```conf
default-locale English-US
default-display-language English-US
default-keyboard-set English-US
```

`Unix/config/obsidian.local.conf`:

```conf
directory $DEV/MyVault
settings Obsidian/.obsidian
```

## Related

- [`Bootstrap` in the Bootstrap module reference](../../modules/Bootstrap.md#bootstrap)
- [Bootstrap a Mac](../../bootstrap.md)
- [Bootstrap configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
