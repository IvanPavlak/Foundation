# Update-AiArtifacts

Vendors AI skills, mods, rules, prompts and agents from the upstream repositories of
`ai-artifacts.conf` into `<root>/<Kind>/<source>/`, pinned to an exact commit, or with `--check`
reports which sources are behind.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `root PATH` | `$DOTFILES_ROOT/AI` | Where the sources are vendored, `<root>/<Kind>/<Source>/`; Deploy-AiArtifacts reads from the same root |
| [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `[Source]` | none, the base file holds no source | One upstream source; `Update-AiArtifacts Source` picks it by name |
| [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `repository OWNER/NAME` | none (required) | The GitHub repository; anything not in `owner/name` form is an error for that source |
| [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `ref REF` | `main` | The branch, tag or commit to pin; resolved to an exact commit on every run |
| [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `skills\|mods\|rules\|prompts\|agents PATH...` | `skills skills` when the section names no kind | The upstream folders holding that kind's items, `.` for the repository root |
| [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `exclude ITEM...` | none | Item names not to vendor |
| [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `skip NAME...` | `.git .github tests design docs` | Top-level entries of an item not to copy; an empty `skip` line copies everything |
| [`ai-harnesses.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | - | - | Not used here: the library this command shares with Deploy-AiArtifacts reads it |

## Decisions

1. Which upstream repositories should the repository vendor artifacts from?
    - Options: one `[Source]` section per repository, named as its folders under `AI/<Kind>/` should be, with a `repository MyOwner/MyRepo` line. A private repository needs a GitHub token (`GITHUB_TOKEN`, `GH_TOKEN` or a signed-in `gh`).
    - Default: no sources; the command warns that there is nothing to vendor and exits 0.
    - More detail: [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf)
2. Which kinds does each source feed, and from which folders?
    - Options: one line per kind (`skills skills/engineering`, `agents agents`, `mods .` for a repository whose root is the mod).
    - Default: `skills skills`.
    - More detail: [AI on a Mac](../../ai.md#vendoring)
3. Which version of each source should be pinned?
    - Options: `ref` with a branch (follows it on every run), a tag, or a commit (stays put).
    - Default: `main`.
    - More detail: [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf)
4. Should any upstream item, or any part of an item, be left out?
    - Options: `exclude` with item names; `skip` with top-level entry names.
    - Default: every item found, without `.git .github tests design docs`.
    - More detail: [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf)

## Where to Put Values

`Unix/config/ai-artifacts.local.conf`, created when missing. Each `[Source]` section there adds a
source; a section with the name of a base one replaces it whole. The vendored folders take the
section name as written, so keep it stable: a renamed section vendors into new folders and leaves
the old ones in place.

## Steps Overview

1. Add the source section
2. Check the configuration

## Step 1: Add the source section

```conf
[MySource]
repository  MyOwner/MyRepo
ref         main
skills      skills
```

Re-running replaces only the items the previous `UPSTREAM.md` of each kind folder lists, so a
folder you made by hand under `AI/Skills/MySource/` survives. The vendored items reach the apps
through [Deploy-AiArtifacts](Deploy-AiArtifacts.md).

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
Update-AiArtifacts MySource --check
```

`--check` resolves `ref` and reports an unknown source, a `repository` not in `owner/name` form, or
a `ref` that does not resolve, and otherwise whether the source is not vendored yet, up to date, or
behind.

## Verification

```bash
Update-AiArtifacts --check
cat AI/Skills/MySource/UPSTREAM.md
List-AiArtifacts --source MySource
```

## Complete Example

`Unix/config/ai-artifacts.local.conf`:

```conf
[MySource]
repository  MyOwner/MyRepo
ref         v1.2.0
skills      skills/engineering skills/writing
agents      agents
exclude     my-unwanted-skill
skip        .git tests
```

## Related

- [`Update-AiArtifacts` in the AI module reference](../../modules/AI.md#update-aiartifacts)
- [Deploy-AiArtifacts](Deploy-AiArtifacts.md)
- [AI configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
