# Deploy-AiArtifacts

Links the repository's AI skills, mods, rules, prompts and agents into the AI apps this Mac deploys
into, or with `--check` reports what a run would change.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `deploy HARNESS...` | none: nothing is deployed | The apps this machine deploys into, sections of `ai-harnesses.conf`; the last line for the machine type wins |
| [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `exclude KIND/NAME...` | none | Items not to deploy: `skills/tdd` from every source, `skills/foundation/document` from one |
| [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `use KIND NAME` | `use rules CoreAiRules` | The item a `file` destination of that kind links (the rules); the last line per kind wins |
| [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `root PATH` | `$DOTFILES_ROOT/AI` | The artifacts root, `<root>/<Kind>/<source>/<item>` |
| [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `[Source]` | none | A vendored source folder that is read (besides `own`, `foundation` and `example`) |
| [`ai-harnesses.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `[Harness]` | `claude-code`, `codex`, `gemini-cli`, `copilot`, all inactive | One app and its destinations |
| [`ai-harnesses.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `KIND PLACEMENT FILES [+HOOK...] PATH` | the catalogue on [AI on a Mac](../../ai.md#the-base-catalogue) | One destination: `each`, `copy` or `file`; the files to take from an item; the hooks `+claude-plugin-dirs` and `+managed-settings`; the path |
| [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `[Source]` with `checkout PATH` | none | A checkout source: the items under its kind folders (`skills skills` without a kind line) are linked from that local repository in place |
| [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `[Source]` with `manifest FILE` | none | A manifest source: its rows are linked from their pinned clones in `~/.local/share/foundation/ai-manifests/`, fetched through git first when missing (not under `--check`; a failed fetch is a warning) |
| [`ai-profiles.conf`](../../configuration.md#ai-profilesconf) | `[Profile]` and its `deploy`, `rules`, `include`, `exclude`, `plan`, `owns`, `autonomous`, `policy`, `default-policy`, `merge-without-checks`, `unattended` lines; `shared`, `default-owner` | none: profiles off | With a profile: its harnesses, rules item, included and excluded items, the manifest rows of its scope, and what the managed settings copy pins, wires (the ownership guard and the repository policy hook) and writes next to it (`ai-profile.conf`) |
| [`repositories.conf`](../../configuration.md#repositoriesconf) | `NAME PATH-OR-URL DIR` | the repository itself | Where a `repo:NAME` manifest row is linked (`DIR/.claude/skills/`) |

## Decisions

1. Which AI apps should this Mac deploy into?
    - Options: a `deploy` line naming harnesses of the catalogue (`deploy claude-code codex`), and `@TYPE deploy ...` lines after it for machine types that differ.
    - Default: none; the command warns that there is no harness and exits 0.
    - More detail: [AI on a Mac](../../ai.md#harnesses)
2. Should any item be left out?
    - Options: `exclude` lines, `KIND/NAME` for every source or `KIND/SOURCE/NAME` for one (`exclude skills/foundation/foundation-configurator`).
    - Default: every item of every source read is deployed.
    - More detail: [AI on a Mac](../../ai.md#artifacts)
3. Which rules should the apps' global instruction files link to?
    - Options: your own rules in `AI/Rules/own/<Name>/RULES.md` (plus a `managed-settings.json` for Claude Code's enforcement layer) and `use rules <Name>`; `exclude rules/example/<Name>` when it shares the example's name.
    - Default: the example skeleton `AI/Rules/example/CoreAiRules`.
    - More detail: [AI on a Mac](../../ai.md#rules)
4. Does an app the catalogue lacks need its own definition?
    - Options: a `[MyApp]` section in `ai-harnesses.local.conf` with one destination line per kind it reads, and its name on the `deploy` line.
    - Default: the catalogue only.
    - More detail: [`ai-harnesses.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf)
5. Where in the repository do the artifacts live?
    - Options: a `root` line with a path (`~` and `$VARIABLES` expand).
    - Default: `AI` of the repository.
    - More detail: [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf)

## Where to Put Values

`Unix/config/ai-artifacts.local.conf` and `Unix/config/ai-harnesses.local.conf`, created when
missing. Lines before the first section are added to the base ones (`-LINE` takes a base line
back); a `[Section]` replaces the base one of the same name whole. Every line may start with `@TYPE`.

## Steps Overview

1. Turn on the harnesses
2. Name the rules and the exclusions
3. Check the configuration

## Step 1: Turn on the harnesses

```conf
deploy claude-code codex
@Work deploy claude-code
```

## Step 2: Name the rules and the exclusions

```conf
use rules CoreAiRules
exclude rules/example/CoreAiRules skills/my-unwanted-skill
```

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
Deploy-AiArtifacts --check
```

`Test-ConfigurationSchema` reports a `deploy` name that is no harness, a malformed destination
line, an unknown hook and a malformed `exclude` or `use` line; `--check` names every link that is
missing or wrong.

## Verification

```bash
Deploy-AiArtifacts --check
List-AiArtifacts --list-discrepancies
readlink ~/.claude/CLAUDE.md
```

## Complete Example

`Unix/config/ai-artifacts.local.conf`:

```conf
deploy claude-code codex gemini-cli
@Work deploy claude-code
exclude rules/example/CoreAiRules skills/my-unwanted-skill
use rules CoreAiRules
```

`Unix/config/ai-harnesses.local.conf`:

```conf
[my-app]
skills   each  .                   ~/.my-app/skills
rules    file  my-app.md,RULES.md  ~/.my-app/INSTRUCTIONS.md
```

## Related

- [`Deploy-AiArtifacts` in the AI module reference](../../modules/AI.md#deploy-aiartifacts)
- [List-AiArtifacts](List-AiArtifacts.md)
- [AI configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
