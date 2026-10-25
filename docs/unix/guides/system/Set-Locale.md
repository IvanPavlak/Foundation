# Set-Locale

Sets the macOS region (date, number and unit formats) to a `locale` of `language.conf`, keeping
the display language.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`language.conf`](../../configuration.md#files) | `locale NAME CODE` | none | A region the menu offers; only the region of CODE counts (`de-DE` is `DE`), written into `AppleLocale` as `@rg=dezzzz` |
| [`language.conf`](../../configuration.md#files) | `default-locale NAME` | none | What Enter picks in the menu |

## Decisions

1. Which regions should this Mac switch between?
    - Options: one `locale NAME CODE` line each; NAME is one word (`German`), CODE is `language-REGION` (`de-DE`, `en-GB`). A code without a region stops the run. A later line for the same NAME (case-insensitive) replaces an earlier one.
    - Default: none, so the command warns and changes nothing.
    - More detail: [`language.conf`](../../configuration.md#files)
2. Which region should Enter pick in the menu?
    - Options: `default-locale NAME`, naming a `locale` entry; the last line for this machine type wins.
    - Default: none, so Enter without a selection fails with an error.
    - More detail: [`language.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/language.local.conf`, created when missing. `language.conf` has no sections: the
overlay's lines are added after the base lines (the base ships none), a later line for the same
NAME replaces an earlier one, `-LINE` takes a base line back and `@TYPE` limits a line to machine
types (`@Laptop default-locale UK`).

## Steps Overview

1. Add the locales
2. Choose the default
3. Check the configuration

## Step 1: Add the locales

```conf
locale  German  de-DE
locale  UK      en-GB
```

## Step 2: Choose the default

```conf
default-locale  German
```

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `@TYPE` prefix that names a machine type `machines.conf` does not have; a
`default-locale` that names no entry shows only when Enter picks it.

## Verification

```bash
Test-ConfigurationSchema --quiet
Display-SystemLanguageSettings
```

The Region line shows the configured name of the current region, and the Defaults block names
the default.

## Complete Example

`Unix/config/language.local.conf`:

```conf
locale          German  de-DE
locale          UK      en-GB
default-locale  German
@Laptop default-locale UK
```

## Related

- [`Set-Locale` in the System module reference](../../modules/System.md#set-locale)
- [System configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
