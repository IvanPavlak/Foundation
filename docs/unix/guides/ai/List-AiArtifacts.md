# List-AiArtifacts

Lists the AI skills, mods, rules, prompts and agents the repository carries, as Deploy-AiArtifacts
reads them, or with `--list-discrepancies` what is not deployed.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `root PATH` | `$DOTFILES_ROOT/AI` | The artifacts root listed |
| [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `[Source]`, `exclude KIND/NAME...` | none | Which source folders are read besides `own`, `foundation` and `example`, and which items are left out |
| [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `deploy HARNESS...`, `use KIND NAME` | none; `use rules CoreAiRules` | What `--list-discrepancies` expects deployed |
| [`ai-harnesses.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `[Harness]` and its destination lines | the inactive catalogue | Where `--list-discrepancies` looks |

## Decisions

1. Which artifacts should the repository carry and deploy?
    - Options: the decisions of [Deploy-AiArtifacts](Deploy-AiArtifacts.md#decisions) and [Update-AiArtifacts](Update-AiArtifacts.md#decisions); this command only reads them.
    - Default: the product skills, the example rules and `own` (empty).
    - More detail: [AI on a Mac](../../ai.md)

## Where to Put Values

`Unix/config/ai-artifacts.local.conf` and `ai-harnesses.local.conf`, as for
[Deploy-AiArtifacts](Deploy-AiArtifacts.md#where-to-put-values).

## Steps Overview

1. Configure the artifacts
2. Check the configuration

## Step 1: Configure the artifacts

```conf
deploy claude-code
exclude skills/my-unwanted-skill
```

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
List-AiArtifacts --kind skills --quiet
```

## Verification

```bash
List-AiArtifacts
List-AiArtifacts --list-discrepancies
```

## Complete Example

`Unix/config/ai-artifacts.local.conf`:

```conf
deploy claude-code codex
exclude skills/my-unwanted-skill rules/example/CoreAiRules
use rules CoreAiRules
```

## Related

- [`List-AiArtifacts` in the AI module reference](../../modules/AI.md#list-aiartifacts)
- [Deploy-AiArtifacts](Deploy-AiArtifacts.md)
- [AI configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
