# Open-Acrobat

Opens every PDF of the named groups of `pdfs.conf` in Adobe Acrobat, or in the default PDF viewer
when Acrobat is not installed; without any argument it opens Acrobat itself, and `--pdf ''` shows a menu of the groups and the recently used PDFs.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`pdfs.conf`](../../configuration.md#files) | `[Group]` | none, only a commented example | A PDF group Open-Acrobat opens by name; the menu lists every section |
| [`pdfs.conf`](../../configuration.md#files) | `PATH` | none | One PDF of the group per line (`~` and `$VARIABLES` expand, spaces are kept) |
| [`apps.conf`](../../configuration.md#files) | `app Acrobat BUNDLE-ID` | `app Acrobat com.adobe.Reader` | The Acrobat the PDFs open in, when Spotlight finds that bundle id installed; otherwise the default PDF viewer |

## Decisions

1. Which groups of PDFs should open together?
    - Options: one `[Group]` section per group, named as you type it (`Open-Acrobat MyProject`, or several: `Open-Acrobat MyProject,Learning`, also after `--pdf` as on Windows).
    - Default: no groups; the menu is empty and an empty Enter opens Acrobat itself.
    - More detail: [`pdfs.conf`](../../configuration.md#files)
2. Which PDFs are in each group?
    - Options: one path per line; a file that does not exist is reported and the rest still open.
    - Default: none.
    - More detail: [Shared format](../../configuration.md#shared-format)
3. Which Acrobat should open them?
    - Options: the bundle id on the `app Acrobat` line (`com.adobe.Reader` for Acrobat Reader, `com.adobe.Acrobat.Pro` for Acrobat Pro).
    - Default: Acrobat Reader; without it installed, the default PDF viewer (Preview).
    - More detail: [`apps.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/pdfs.local.conf`, created when missing. A `[Group]` section there adds the group; a
section with the name of a base one replaces it whole. `@TYPE` limits a path line to machine
types. In `Unix/config/apps.local.conf` the last `app Acrobat` line wins, so an overlay line
replaces the base one; no `-LINE` is needed.

## Steps Overview

1. Add the PDF group
2. Choose the Acrobat
3. Check the configuration

## Step 1: Add the PDF group

```conf
[MyProject]
~/Documents/MyProject/Specification.pdf
$DEV/MyProject/docs/Design Notes.pdf
```

## Step 2: Choose the Acrobat

Only when it is not Acrobat Reader, in `apps.local.conf`:

```conf
app Acrobat com.adobe.Acrobat.Pro
```

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
grep -n -A5 '^\[MyProject\]' Unix/config/pdfs.local.conf
```

Test-ConfigurationSchema checks the PDF groups `dnd.conf` names; the paths themselves are checked
when the group opens.

## Verification

```bash
cat Unix/config/pdfs.local.conf
ls -l ~/Documents/MyProject/Specification.pdf
mdfind "kMDItemCFBundleIdentifier == 'com.adobe.Reader'"
```

## Complete Example

`Unix/config/pdfs.local.conf`:

```conf
[MyProject]
~/Documents/MyProject/Specification.pdf
$DEV/MyProject/docs/Design Notes.pdf

[Learning]
~/Documents/Books/Some Book.pdf
@Laptop ~/Documents/Books/Another Book.pdf
```

`Unix/config/apps.local.conf`:

```conf
app Acrobat com.adobe.Acrobat.Pro
```

## Related

- [`Open-Acrobat` in the Application module reference](../../modules/Application.md#open-acrobat)
- [Application configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
