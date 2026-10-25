# Invoke-GoogleTranslate

Translates text with Google Translate (alias `translate`), detecting the source language and
translating into the default target language of `translate.conf` unless the flags name others.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`translate.conf`](../../configuration.md#files) | `output LANGUAGE` | `English` | The target language when `--output-language` is not given |

## Decisions

1. Which language should text be translated into by default?
    - Options: an English language name (`German`, `Croatian`, `Chinese`) or its code (`de`, `hr`, `zh-CN`) from the list the command knows; `--output-language` overrides it per call.
    - Default: `English`, also when the file or the line is missing.
    - More detail: [`translate.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/translate.local.conf`, created when missing. The file has no sections: its lines are
added after the base ones and the last `output` line wins. An `@TYPE` prefix gives a machine type
its own target. The source language is not configurable: it is detected unless
`--input-language` names one (`auto`, `detect` and `automatic` detect it too).

## Steps Overview

1. Set the target language
2. Check the configuration

## Step 1: Set the target language

```conf
output German
```

An unknown name stops every call with `Unsupported output language` and the list of supported names.

## Step 2: Check the configuration

```bash
translate hello
```

The answer starts with the target language in brackets (`[German] => ...`).
`Test-ConfigurationSchema` does not check this file.

## Verification

```bash
cat Unix/config/translate.local.conf
translate good morning
```

## Complete Example

`Unix/config/translate.local.conf`:

```conf
output German
@Work output English
```

## Related

- [`Invoke-GoogleTranslate` in the Helper module reference](../../modules/Helper.md#invoke-googletranslate)
- [Helper configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
