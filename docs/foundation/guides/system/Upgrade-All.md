# Upgrade-All

Upgrades the named package managers (Homebrew and the App Store by default, macOS updates only when named), pinning the Homebrew formulae `package-pins.conf` lists first and skipping them.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`package-pins.conf`](../../configuration.md#package-pinsconf) | `brew FORMULA` | none | A Homebrew formula kept at its installed version: pinned (`brew pin`) before `brew upgrade`. A formula of a bundled Brewfile that is pinned without a line is unpinned; a pin on a formula no Brewfile names is left alone |
| [`bootstrap.conf`](../../configuration.md#bootstrapconf) | `[Packages]` `brewfile PATH` | `Unix/Brewfile`, then `Unix/Brewfile.local` | The Brewfiles whose formulae count as managed: the only ones whose pin Upgrade-All removes |

The App Store and macOS updates read no configuration: mas and softwareupdate cannot pin.

## Decisions

1. Which formulae should never be upgraded?
    - Options: one `brew FORMULA` line per formula (`brew node`), `@TYPE` for one machine type. Homebrew keeps the installed version and cannot pin a cask. Taking a line back (`-brew node`) unpins the formula at the next run.
    - Default: none: every formula is upgraded.
    - More detail: [`package-pins.conf`](../../configuration.md#package-pinsconf)

## Where to Put Values

`Unix/config/package-pins.local.conf`, created when missing. The file has no sections: the
overlay's lines are added after the base lines, and `-LINE` takes a base line back
(`-brew node`). `@TYPE` limits a line to machine types.

## Steps Overview

1. Add the pin lines
2. Run the upgrade

## Step 1: Add the pin lines

```conf
brew node
@Work brew postgresql@16
```

## Step 2: Run the upgrade

```bash
Upgrade-All Homebrew
```

The listed formulae that are installed are pinned before `brew upgrade` runs; a formula not
installed yet is reported and pinned by the first run after it is.

## Verification

```bash
brew list --pinned
```

Every installed formula with a line is listed, and no formula of the Brewfiles without one.

## Complete Example

`Unix/config/package-pins.local.conf`:

```conf
brew node
@Work brew postgresql@16
```

```bash
Upgrade-All
Upgrade-All Homebrew,MacOS
```

## Related

- [`Upgrade-All` in the System module reference](../../modules/System.md#upgrade-all)
- [System configuration guides](README.md)
