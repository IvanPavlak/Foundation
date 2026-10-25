# Set-KeyboardLayouts

Applies a `keyboard-set` of `language.conf`: enables its layouts, selects the first and disables
every other keyboard layout, live with no logout.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`language.conf`](../../configuration.md#files) | `keyboard-layout NAME ID` | none | A layout a set can name, by its input-source id (`com.apple.keylayout.US`) |
| [`language.conf`](../../configuration.md#files) | `keyboard-set NAME LAYOUT...` | none | A set the menu offers: an ordered list of `keyboard-layout` names, the first one selected |
| [`language.conf`](../../configuration.md#files) | `default-keyboard-set NAME` | none | What Enter picks in the menu |

## Decisions

1. Which keyboard layouts does this Mac use?
    - Options: one `keyboard-layout NAME ID` line each; NAME is one word (`US`), ID the input-source id. `Display-SystemLanguageSettings` prints the ids of the enabled layouts. A later line for the same NAME (case-insensitive) replaces an earlier one.
    - Default: none.
    - More detail: [`language.conf`](../../configuration.md#files)
2. Which sets of layouts should the command switch between?
    - Options: one `keyboard-set NAME LAYOUT...` line each, naming `keyboard-layout` entries in order; the first is the selected one. A name that is not a `keyboard-layout`, or an id this Mac does not have, stops the run before anything changes.
    - Default: none, so the command warns and changes nothing.
    - More detail: [`language.conf`](../../configuration.md#files)
3. Which set should Enter pick in the menu?
    - Options: `default-keyboard-set NAME`, naming a `keyboard-set`; the last line for this machine type wins.
    - Default: none, so Enter without a selection fails with an error.
    - More detail: [`language.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/language.local.conf`, created when missing. `language.conf` has no sections: the
overlay's lines are added after the base lines (the base ships none), a later line for the same
NAME replaces an earlier one, `-LINE` takes a base line back and `@TYPE` limits a line to machine
types (`@Laptop default-keyboard-set US-Only`).

## Steps Overview

1. Add the layouts
2. Add the sets and the default
3. Check the configuration

## Step 1: Add the layouts

`Display-SystemLanguageSettings` lists the ids of the enabled layouts; enable a new one once in
System Settings to learn its id.

```conf
keyboard-layout  German  com.apple.keylayout.German
keyboard-layout  US      com.apple.keylayout.US
```

## Step 2: Add the sets and the default

```conf
keyboard-set          German-US  German US
keyboard-set          US-Only    US
default-keyboard-set  German-US
```

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `@TYPE` prefix that names a machine type `machines.conf` does not have; a set
naming an unknown layout shows only when that set is applied.

## Verification

```bash
Test-ConfigurationSchema --quiet
Display-SystemLanguageSettings
```

The enabled layouts show their configured names, the selected one marked.

## Complete Example

`Unix/config/language.local.conf`:

```conf
keyboard-layout       German     com.apple.keylayout.German
keyboard-layout       US         com.apple.keylayout.US
keyboard-set          German-US  German US
keyboard-set          US-Only    US
default-keyboard-set  German-US
@Laptop default-keyboard-set US-Only
```

## Related

- [`Set-KeyboardLayouts` in the System module reference](../../modules/System.md#set-keyboardlayouts)
- [System configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
