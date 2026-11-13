# Switch-AiProfile

Switches this Mac to another AI profile in one call: it records the pick in the root-owned switch file, redeploys the rules and the managed settings, and runs `Test-AiProfile`.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`ai-profiles.conf`](../../configuration.md#ai-profilesconf) | `[Profile]` | none: profiles are off and the command exits 2 | The profiles the Mac can be switched to |
| [`ai-profiles.conf`](../../configuration.md#ai-profilesconf) | `host NAME PROFILE`, `default PROFILE` | none | The profile `--reset` returns the Mac to |
| [`ai-harnesses.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `rules file managed-settings.json +managed-settings PATH` | `/Library/Application Support/ClaudeCode/managed-settings.json` (`claude-code`) | The folder that holds the switch file `ai-profile.switch`; without such a destination there is nothing to switch |

The switch file itself is not configuration: `Switch-AiProfile` writes it through sudo, and every AI command reads it after `FOUNDATION_AI_PROFILE` and before the `host` and `default` lines.

## Decisions

1. Which profiles should this Mac be able to run?
    - Options: one `[Profile]` section per profile, each with its `rules` and `plan` lines.
    - Default: none; with no profile section the command exits 2.
    - More detail: [AI on a Mac](../../ai.md#profiles)
2. Which profile is the Mac's own, the one `--reset` returns to?
    - Options: a `host NAME PROFILE` line for this Mac, or the `default` line.
    - Default: none; after a reset no profile is active.
    - More detail: [`ai-profiles.conf`](../../configuration.md#ai-profilesconf)
3. Where do the managed settings, and with them the switch file, live?
    - Options: the `+managed-settings` destination of a harness (the base `claude-code` harness has it).
    - Default: `/Library/Application Support/ClaudeCode`.
    - More detail: [AI on a Mac](../../ai.md#the-base-catalogue)

## Where to Put Values

`Unix/config/ai-profiles.local.conf`, created when missing. Its lines before the first section come after the base file's, so its `host` and `default` lines win; its sections are the profiles.

## Steps Overview

1. Name the profiles
2. Preview the switch
3. Switch

## Step 1: Name the profiles

```conf
default Personal

[Personal]
rules  Personal
plan   Max 00000000-0000-0000-0000-000000000000

[Work]
rules  Work
plan   Team 11111111-1111-1111-1111-111111111111
```

## Step 2: Preview the switch

```bash
Switch-AiProfile Work --dry-run
```

It names the switch file and lists what `Deploy-AiArtifacts --kind rules` would change as the Work profile; nothing is written and sudo is not asked.

## Step 3: Switch

```bash
Switch-AiProfile Work
```

sudo asks for the password once. Add `--full` to bring the skills, MCP servers and marketplaces over too, and `Switch-AiProfile --reset` to return to the Mac's own profile. Afterwards restart every open Claude Code session and, when `Test-AiProfile` names another Plan, sign in to it (`/login`).

## Verification

```bash
Test-AiProfile
Switch-AiProfile Work --dry-run
```

`Test-AiProfile` prints the profile and how it was picked (`switched` after a switch). `Switch-AiProfile` without arguments prints the same with the switch file, then offers the profiles in a menu, where Enter changes nothing.

## Complete Example

`Unix/config/ai-profiles.local.conf`:

```conf
host My-Work-Mac Work
default Personal

[Personal]
rules         Personal
plan          Max 00000000-0000-0000-0000-000000000000

[Work]
rules         Work
plan          Team 11111111-1111-1111-1111-111111111111
mcp
```

## Related

- [`Switch-AiProfile` in the AI module reference](../../modules/AI.md#switch-aiprofile)
- [AI configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
