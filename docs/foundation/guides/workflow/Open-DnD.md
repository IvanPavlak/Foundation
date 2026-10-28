# Open-DnD

Opens a D&D campaign of `dnd.conf`: Obsidian, the campaign's PDF group and its browser group.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`dnd.conf`](../../configuration.md#files) | `[Campaign]` | none (a commented example) | A campaign; the menu lists the sections in file order |
| [`dnd.conf`](../../configuration.md#files) | `pdf GROUP` | none | The `pdfs.conf` group (the character sheet) opened with Open-Acrobat |
| [`dnd.conf`](../../configuration.md#files) | `browser GROUP` | none | The `browser-groups.conf` group (the spell list) opened with Open-Browser |

## Decisions

1. Which campaigns should Open-DnD offer?
    - Options: one `[Campaign]` section per campaign, in the order the menu should show them.
    - Default: none; the menu is empty and nothing opens.
    - More detail: [Files](../../configuration.md#files)
2. Which PDFs belong to the campaign?
    - Options: one `pdf GROUP` line naming a group of `pdfs.conf` (Open-Acrobat).
    - Default: no line, no PDF opens; Obsidian still opens.
    - More detail: [`Open-Acrobat`](../../modules/Application.md#open-acrobat)
3. Which web pages belong to the campaign?
    - Options: one `browser GROUP` line naming a group (or named URL) of `browser-groups.conf`.
    - Default: no line, no browser window opens.
    - More detail: [`browser-groups.conf`](../../configuration.md#browser-groupsconf)

## Where to Put Values

`Unix/config/dnd.local.conf`, created when missing. A `[MyCampaign]` section there adds the
campaign; a section with the name of a base one replaces it whole. A campaign has one `pdf` and one
`browser` group, as on Windows: with several lines of a kind the last one wins. The groups they name live in `pdfs.local.conf` and `browser-groups.local.conf`;
the Obsidian vault Open-Obsidian opens is set in `obsidian.conf`.

## Steps Overview

1. Add the campaign section
2. Check the configuration

## Step 1: Add the campaign section

```conf
[MyCampaign]
pdf      MyCharacter
browser  MySpells
```

`MyCharacter` must be a group of `pdfs.conf` and `MySpells` a group of `browser-groups.conf`.

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports a `pdf` group missing from `pdfs.conf` and a `browser` group missing from
`browser-groups.conf`.

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n -A2 '^\[MyCampaign\]' Unix/config/dnd.local.conf
```

## Complete Example

`Unix/config/dnd.local.conf`:

```conf
[MyCampaign]
pdf      MyCharacter
browser  MySpells

[MyOtherCampaign]
browser  MyOtherSpells
```

## Related

- [`Open-DnD` in the Workflow module reference](../../modules/Workflow.md#open-dnd)
- [Workflow configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
