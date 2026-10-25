# Display-SystemLanguageSettings

Prints the display languages, the region and the enabled keyboard layouts of this Mac, naming
each value `language.conf` configures, and changes nothing.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`language.conf`](../../configuration.md#files) | `display-language NAME CODE` | none | The name shown after a display language whose code is CODE (`en-US`) |
| [`language.conf`](../../configuration.md#files) | `locale NAME CODE` | none | The name shown after the region when the region of CODE (`de-DE` is `DE`) matches |
| [`language.conf`](../../configuration.md#files) | `keyboard-layout NAME ID` | none | The name shown after an enabled layout whose input-source id is ID |
| [`language.conf`](../../configuration.md#files) | `default-display-language NAME` | none | Listed under the closing Defaults block |
| [`language.conf`](../../configuration.md#files) | `default-locale NAME` | none | Listed under the closing Defaults block |
| [`language.conf`](../../configuration.md#files) | `default-keyboard-set NAME` | none | Listed under the closing Defaults block |

The command only labels what it prints; the lines take effect through
[Set-DisplayLanguage](Set-DisplayLanguage.md), [Set-Locale](Set-Locale.md) and
[Set-KeyboardLayouts](Set-KeyboardLayouts.md), whose guides cover them in full.

## Decisions

1. Which display languages, regions and keyboard layouts should carry a configured name?
    - Options: `display-language NAME CODE`, `locale NAME CODE` and `keyboard-layout NAME ID` lines; NAME is one word, CODE a language tag (`en-US`) or `language-REGION` (`de-DE`), ID an input-source id (`com.apple.keylayout.US`). A later line for the same NAME (case-insensitive) replaces an earlier one.
    - Default: none, so every value prints without a name.
    - More detail: [`language.conf`](../../configuration.md#files)
2. Which entries are the defaults the Set- commands pick on Enter?
    - Options: one `default-display-language NAME`, `default-locale NAME` and `default-keyboard-set NAME` line each, naming an entry above; the last line for this machine type wins.
    - Default: none, so the Defaults block is left out.
    - More detail: [`language.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/language.local.conf`, created when missing. `language.conf` has no sections: the
overlay's lines are added after the base lines (the base ships none), a later line for the same
NAME replaces an earlier one, `-LINE` takes a base line back and `@TYPE` limits a line to machine
types.

## Steps Overview

1. Look up the codes and ids
2. Add the entries
3. Check the configuration

## Step 1: Look up the codes and ids

Run the command once before configuring anything: it prints the `AppleLanguages` codes, the
`AppleLocale` value and the input-source id of every enabled keyboard layout, the values the
lines below take.

```bash
Display-SystemLanguageSettings
```

## Step 2: Add the entries

```conf
display-language          English-US   en-US
locale                    German       de-DE
keyboard-layout           German       com.apple.keylayout.German
keyboard-layout           US           com.apple.keylayout.US
default-display-language  English-US
default-locale            German
default-keyboard-set      German-US
```

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `@TYPE` prefix that names a machine type `machines.conf` does not have; it does
not check the language entries themselves.

## Verification

```bash
Test-ConfigurationSchema --quiet
Display-SystemLanguageSettings
```

Each configured value now shows its name in parentheses, and the Defaults block closes the
listing.

## Complete Example

`Unix/config/language.local.conf`:

```conf
display-language          English-US   en-US
display-language          German       de-DE
locale                    German       de-DE
keyboard-layout           German       com.apple.keylayout.German
keyboard-layout           US           com.apple.keylayout.US
keyboard-set              German-US    German US
default-display-language  English-US
default-locale            German
default-keyboard-set      German-US
```

## Related

- [`Display-SystemLanguageSettings` in the System module reference](../../modules/System.md#display-systemlanguagesettings)
- [System configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
