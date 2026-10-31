# Test-AiProfile

Checks that this Mac runs the AI profile it should, that Claude Code is signed in to that profile's Plan and pinned to it, and that no pay-per-use credential is set; changes nothing.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`ai-profiles.conf`](../../configuration.md#ai-profilesconf) | `[Profile]` | none: profiles are off and the command exits 2 | The profiles a machine can run |
| [`ai-profiles.conf`](../../configuration.md#ai-profilesconf) | `host NAME PROFILE` | none | The profile of the Mac whose local hostname is NAME |
| [`ai-profiles.conf`](../../configuration.md#ai-profilesconf) | `default PROFILE` | none | The profile of every other Mac |
| [`ai-profiles.conf`](../../configuration.md#ai-profilesconf) | `plan NAME UUID...` | none: a mismatch | The Plan Claude Code must be signed in to, and the managed settings must pin |
| [`ai-profiles.conf`](../../configuration.md#ai-profilesconf) | `deploy HARNESS...`, `mcp NAME...`, `unattended on\|off` | the `deploy` line of `ai-artifacts.conf`, every server, off | Where the managed settings are looked for, which OAuth servers are listed, what is printed for unattended runs |
| [`ai-profiles.conf`](../../configuration.md#ai-profilesconf) | `policy LEVEL PATTERN...`, `autonomous PATTERN...`, `default-policy LEVEL`, `merge-without-checks PATTERN...` | `branch` for every repository, no merge without checks | The repository policy listed (never a mismatch); see [Repository policies](../../ai.md#repository-policies) |
| [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `deploy HARNESS...` | none | The harnesses whose `+managed-settings` destination is checked, without a profile `deploy` line |
| [`ai-harnesses.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `rules file managed-settings.json +managed-settings PATH` | `/Library/Application Support/ClaudeCode/managed-settings.json` (`claude-code`) | The managed settings file whose `forceLoginOrgUUID` is compared |
| [`ai-mcp-servers.conf`](../../configuration.md#files) | `[Server]` with a `url` line | none | A remote server without `bearer-token-env` or an `Authorization` header is listed as an OAuth server |

`FOUNDATION_AI_PROFILE` overrides the host and default lines. `~/.claude.json` (`$CLAUDE_CONFIG_DIR/.claude.json` when set) is only read, for its `oauthAccount` block.

## Decisions

1. Which profile should this Mac run?
    - Options: a `host NAME PROFILE` line for this Mac, or the `default` line; `FOUNDATION_AI_PROFILE` for one shell.
    - Default: none; with no profile section the command exits 2.
    - More detail: [AI on a Mac](../../ai.md#profiles)
2. Which Plan does each profile use?
    - Options: `plan NAME UUID...` with the organization UUID(s) of that Plan.
    - Default: none, reported as a mismatch.
    - More detail: [AI on a Mac](../../ai.md#rules)
3. Where are the managed settings deployed?
    - Options: the `+managed-settings` destination of a harness the machine deploys into (the base `claude-code` harness has it).
    - Default: no harness deployed, reported as a mismatch.
    - More detail: [AI on a Mac](../../ai.md#the-base-catalogue)
4. Which trust level does each repository get, per profile?
    - Options: `policy LEVEL PATTERN...` lines - `autonomous` (also merge a pull request whose CI checks all passed), `branch` (commit, push a feature branch, open pull requests), `draft` (draft pull requests only), `readonly` (no shell, no file edits), `blocked` (no work); the last matching line wins, so broad patterns go first and exceptions after. `default-policy LEVEL` for every other repository; `merge-without-checks PATTERN...` for `autonomous` repositories without CI that may still merge. `autonomous PATTERN...` is a synonym of `policy autonomous`.
    - Default: every repository is at `branch`; nothing merges on its own.
    - More detail: [AI on a Mac - Repository policies](../../ai.md#repository-policies)

## Where to Put Values

`Unix/config/ai-profiles.local.conf`, created when missing. Its lines before the first section come after the base file's, so its `host` and `default` lines win; its sections are the profiles.

## Steps Overview

1. Name the profiles and their Plans
2. Set the repository policy
3. Deploy the managed settings
4. Check the profile

## Step 1: Name the profiles and their Plans

```conf
default Personal

[Personal]
rules  Personal
plan   Max 00000000-0000-0000-0000-000000000000
```

## Step 2: Set the repository policy

```conf
[Personal]
default-policy branch
policy         autonomous github.com/myuser/myproject
```

## Step 3: Deploy the managed settings

```bash
Deploy-AiArtifacts --check
```

## Step 4: Check the profile

```bash
Test-AiProfile; echo "exit $?"
```

## Verification

```bash
Test-ConfigurationSchema --quiet
Test-AiProfile
```

## Complete Example

`Unix/config/ai-profiles.local.conf`:

```conf
host My-Work-Mac Work
default Personal

[Personal]
rules         Personal
plan          Max 00000000-0000-0000-0000-000000000000
unattended    on
default-policy branch
policy        autonomous github.com/myuser/myproject

[Work]
rules         Work
plan          Team 11111111-1111-1111-1111-111111111111
mcp
default-policy draft
```

## Related

- [`Test-AiProfile` in the AI module reference](../../modules/AI.md#test-aiprofile)
- [AI configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
