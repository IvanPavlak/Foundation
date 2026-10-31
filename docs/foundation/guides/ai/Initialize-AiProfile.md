# Initialize-AiProfile

Walks the one-time sign-ins of this Mac's AI profile (Claude Code, the GitHub CLI, the OAuth MCP servers, the profile's environment variables), then runs `Test-AiProfile`. Called by Bootstrap when the opt-in `step AiProfileInit on` is set in `bootstrap.local.conf`.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`ai-profiles.conf`](../../configuration.md#ai-profilesconf) | `[Profile]`, `host NAME PROFILE`, `default PROFILE` | none: the command exits 2 | The profile this Mac runs |
| [`ai-profiles.conf`](../../configuration.md#ai-profilesconf) | `plan NAME UUID...` | none | The Plan the Claude Code sign-in must use, named in the instructions |
| [`ai-profiles.conf`](../../configuration.md#ai-profilesconf) | `mcp NAME...` | every server | Which OAuth servers need their sign-in |
| [`ai-profiles.conf`](../../configuration.md#ai-profilesconf) | `env NAME...` | none | The environment variables the profile needs set on this Mac |
| [`ai-mcp-servers.conf`](../../configuration.md#files) | `[Server]` with a `url` line | none | A remote server without `bearer-token-env` or an `Authorization` header signs in with OAuth |

Nothing is written: every sign-in happens in Claude Code (`/login`, `/mcp`) or `gh auth login` itself, and an environment variable's value goes into `~/.zshenv`, never into the repository.

## Decisions

1. Which environment variables does the profile need?
    - Options: `env NAME...` lines in its section, names only (the API key variable of a `bearer-token-env` server, for one).
    - Default: none.
    - More detail: [AI on a Mac](../../ai.md#profiles)
2. Which MCP servers need a sign-in?
    - Options: the profile's `mcp` lines; every remote server without a token or `Authorization` header is an OAuth server.
    - Default: every configured server.
    - More detail: [AI on a Mac](../../ai.md#mcp-servers)

## Where to Put Values

`Unix/config/ai-profiles.local.conf`, created when missing; each profile is a section there.

## Steps Overview

1. Name the variables
2. Run the walk
3. Optionally let Bootstrap run it

## Step 1: Name the variables

```conf
[Personal]
env  MY_API_KEY
```

## Step 2: Run the walk

```bash
Initialize-AiProfile
```

## Step 3: Optionally let Bootstrap run it

With the step on and a profile active, Bootstrap runs `Initialize-AiProfile` right after the AiMcpServers step and waits at the terminal for each sign-in; `Bootstrap --skip AiProfileInit` runs unattended. In `Unix/config/bootstrap.local.conf`:

```conf
step AiProfileInit on
```

## Verification

```bash
Bootstrap --list
Test-AiProfile
```

## Complete Example

`Unix/config/ai-profiles.local.conf`:

```conf
default Personal

[Personal]
rules  Personal
plan   Max 00000000-0000-0000-0000-000000000000
mcp    my-remote
env    MY_API_KEY
```

## Related

- [`Initialize-AiProfile` in the AI module reference](../../modules/AI.md#initialize-aiprofile)
- [AI configuration guides](README.md)
- [Bootstrap a Mac](../../bootstrap.md#steps)
- [FoundationConfigurator](../../foundation-configurator.md)
