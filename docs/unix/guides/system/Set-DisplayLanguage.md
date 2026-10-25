# Set-DisplayLanguage

Sets the macOS display language to a `display-language` of `language.conf`, the other configured
display languages following as fallbacks.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`language.conf`](../../configuration.md#files) | `display-language NAME CODE` | none | A display language the menu offers; CODE (`en-US`) goes into `AppleLanguages`, the chosen one first and the others after it in file order |
| [`language.conf`](../../configuration.md#files) | `default-display-language NAME` | none | What Enter picks in the menu |

## Decisions

1. Which display languages should this Mac switch between?
    - Options: one `display-language NAME CODE` line each; NAME is one word (`English-US`), CODE a language tag (`en-US`, `de-DE`). File order is the fallback order behind the chosen language. A later line for the same NAME (case-insensitive) replaces an earlier one.
    - Default: none, so the command warns and changes nothing.
    - More detail: [`language.conf`](../../configuration.md#files)
2. Which display language should Enter pick in the menu?
    - Options: `default-display-language NAME`, naming a `display-language` entry; the last line for this machine type wins.
    - Default: none, so Enter without a selection fails with an error.
    - More detail: [`language.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/language.local.conf`, created when missing. `language.conf` has no sections: the
overlay's lines are added after the base lines (the base ships none), a later line for the same
NAME replaces an earlier one, `-LINE` takes a base line back and `@TYPE` limits a line to machine
types (`@Work default-display-language German`).

## Steps Overview

1. Add the display languages
2. Choose the default
3. Check the configuration

## Step 1: Add the display languages

`Display-SystemLanguageSettings` prints the codes this Mac uses now.

```conf
display-language  English-US  en-US
display-language  German      de-DE
```

## Step 2: Choose the default

```conf
default-display-language  English-US
```

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `@TYPE` prefix that names a machine type `machines.conf` does not have; a
`default-display-language` that names no entry shows only when Enter picks it.

## Verification

```bash
Test-ConfigurationSchema --quiet
Display-SystemLanguageSettings
```

The configured languages show their names, and the Defaults block names the default.

## Complete Example

`Unix/config/language.local.conf`:

```conf
display-language          English-US  en-US
display-language          German      de-DE
default-display-language  English-US
@Work default-display-language German
```

## Related

- [`Set-DisplayLanguage` in the System module reference](../../modules/System.md#set-displaylanguage)
- [System configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
