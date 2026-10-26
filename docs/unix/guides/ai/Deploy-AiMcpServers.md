# Deploy-AiMcpServers

Adds the MCP servers of `ai-mcp-servers.conf` to Claude Code (through its CLI, at user scope) and Codex (as tables of `~/.codex/config.toml`), or with `--check` reports what a run would add or update.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`ai-mcp-servers.conf`](../../configuration.md#files) | `deploy APP...` | none: nothing is deployed | The apps this machine adds the servers to, `claude-code` and `codex`; the last line for the machine type wins (`@Work deploy claude-code`) |
| [`ai-mcp-servers.conf`](../../configuration.md#files) | `[Server]` | none, a commented example only | One server, named as both apps list it (letters, digits, `-` and `_`) |
| [`ai-mcp-servers.conf`](../../configuration.md#files) | `url URL` | none | A remote server's http(s) address |
| [`ai-mcp-servers.conf`](../../configuration.md#files) | `transport sse` | `http` | An SSE server, which reaches Claude Code only (Codex reads no SSE servers) |
| [`ai-mcp-servers.conf`](../../configuration.md#files) | `header NAME VALUE` | none | One HTTP header; VALUE is the rest of the line |
| [`ai-mcp-servers.conf`](../../configuration.md#files) | `bearer-token-env NAME` | none | The environment variable holding a token: an `Authorization: Bearer ${NAME}` header for Claude Code, `bearer_token_env_var` for Codex |
| [`ai-mcp-servers.conf`](../../configuration.md#files) | `command PATH` | none | A stdio server's executable; PATH is the rest of the line |
| [`ai-mcp-servers.conf`](../../configuration.md#files) | `arg VALUE` | none | One argument of the command, in order |
| [`ai-mcp-servers.conf`](../../configuration.md#files) | `env NAME VALUE` | none | One variable a stdio server reads |
| [`ai-mcp-servers.conf`](../../configuration.md#files) | `machine TYPE...` | every machine type | The machine types the server is for (an `@TYPE` prefix on a line works too) |

The apps' own files are not configuration: `~/.claude.json` (`$CLAUDE_CONFIG_DIR/.claude.json` when set) is only read, since the `claude` CLI writes it; in `~/.codex/config.toml` (`$CODEX_HOME/config.toml` when set) only the `[mcp_servers.<name>]` tables of the configured servers are written and every other line is kept.

## Decisions

1. Which apps should get the servers on this Mac?
    - Options: `deploy claude-code codex`, or one of the two; an `@TYPE deploy` line after it for a machine type that differs.
    - Default: none; the command warns that there is nothing to deploy.
    - More detail: [AI on a Mac](../../ai.md#mcp-servers)
2. Which servers should every machine have?
    - Options: one `[Server]` section each: a `url` for a remote server, or a `command` with `arg` and `env` lines for one that runs on the machine.
    - Default: none.
    - More detail: [AI on a Mac](../../ai.md#mcp-servers)
3. How does each remote server authenticate?
    - Options: OAuth (most hosted servers): only the `url`, and the sign-in once per machine (`/mcp` in Claude Code, `codex mcp login <name>`), because the tokens stay in the machine's keychain. An API key: `bearer-token-env NAME`, with the key in that environment variable, never in the file. Non-secret headers: `header` lines.
    - Default: OAuth.
    - More detail: [Troubleshooting: AI](../../troubleshooting.md#ai)
4. Is any server for some machine types only?
    - Options: a `machine TYPE...` line in its section.
    - Default: every machine type.
    - More detail: [Configuration](../../configuration.md#base-and-overlay)

## Where to Put Values

`Unix/config/ai-mcp-servers.local.conf`, created when missing. Its `deploy` line comes after the base file's, so it wins; a section there adds a server, one with the name of a base section replaces it whole.

## Steps Overview

1. Name the apps and the servers
2. Check the configuration
3. Sign in to the OAuth servers

## Step 1: Name the apps and the servers

```conf
deploy claude-code codex

[my-remote]
url  https://mcp.example.com/mcp
```

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
Deploy-AiMcpServers --check
```

## Step 3: Sign in to the OAuth servers

```bash
claude            # then /mcp, pick the server and sign in
codex mcp login my-remote
```

## Verification

```bash
Deploy-AiMcpServers --check
claude mcp list
grep '^\[mcp_servers\.' ~/.codex/config.toml
```

## Complete Example

`Unix/config/ai-mcp-servers.local.conf`:

```conf
deploy claude-code codex
@Work deploy claude-code

[my-remote]
url               https://mcp.example.com/mcp

[my-keyed]
url               https://api.example.com/mcp
header            X-Project MyProject
bearer-token-env  MY_API_KEY

[my-local]
command           npx
arg               -y
arg               my-mcp-server
env               LOG_LEVEL info
machine           PC Work
```

## Related

- [`Deploy-AiMcpServers` in the AI module reference](../../modules/AI.md#deploy-aimcpservers)
- [AI configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
