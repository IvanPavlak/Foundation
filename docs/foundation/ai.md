# AI on a Mac

How Foundation deploys the AI artifacts on macOS - the skills, mods, rules, prompts and agents -
into the AI apps a Mac uses, installs the Claude Code plugin marketplaces and adds the MCP servers to Claude Code and Codex. Foundation ships
the mechanism and its own product skills; which artifacts a Mac gets, and into which apps, is the
fork's choice, configured in `Unix/config` overlays like everything else. Why the rules are linked
and why enforcement lives in Claude Code's managed settings is described on WinuX's
[CoreAiRules](https://ivanpavlak.github.io/WinuX/#/winux/ai/coreairules) and [AI Skills](https://ivanpavlak.github.io/WinuX/#/winux/ai/skills) pages; this page holds the
mechanism as Foundation builds it. The commands are on the [AI module page](modules/AI.md).

## Artifacts

An artifact is a folder under the artifacts root (`root` of `ai-artifacts.conf`, default `AI/`
of the repository), kind first: `AI/<Kind>/<source>/<item>/`.

| Kind | Folder | An item is a folder holding | Portable file |
| ---- | ------ | --------------------------- | ------------- |
| skills | `AI/Skills` | `SKILL.md` | `SKILL.md` |
| mods | `AI/Mods` | `.claude-plugin/plugin.json` (a Claude Code mod) | - |
| rules | `AI/Rules` | at least one file (its variants) | `RULES.md` |
| prompts | `AI/Prompts` | at least one file | `PROMPT.md` |
| agents | `AI/Agents` | at least one file | `AGENT.md` |

Formats are never translated: an item is linked as it is. An item folder may carry one file per
app (`claude.md`, `codex.toml`, `copilot.agent.md`, Claude Code's `managed-settings.json`), and each
destination of an app names the files it takes, in order; the portable file is the fallback.

The sources read, in this order, the first winning an item name two of them carry (with a warning):

1. `own` - your own items, never touched by a refresh. It ships empty.
2. Then, in name order: `foundation` (the product skills Foundation ships:
   [foundation-configurator](foundation-configurator.md) and `document`, which turns a command's header into
   its module page entry and guide), `example` (the example rules) and every vendored source, a
   `[section]` of `ai-artifacts.conf` filled by [Update-AiArtifacts](modules/AI.md#update-aiartifacts).

Any other source folder is not read: a repository that carries both halves keeps WinuX's product
skills in `AI/Skills/winux/`, which only Windows deploys. Leave an item out with an `exclude` line:
`exclude skills/tdd` drops it from every source, `exclude skills/foundation/document` from one.

## Harnesses

A harness is an app Deploy-AiArtifacts can deploy into, one `[section]` of
`Unix/config/ai-harnesses.conf`. The base catalogue is inactive: the `deploy` line of
`ai-artifacts.conf` turns harnesses on, and the last one for the machine type wins.

```
deploy claude-code codex
@Work deploy claude-code
```

Each line of a section is one destination, `KIND PLACEMENT FILES [+HOOK...] PATH`:

| Field | Meaning |
| ----- | ------- |
| `KIND` | `skills`, `mods`, `rules`, `prompts` or `agents` |
| `PLACEMENT` | `each`: PATH is a folder, one link per item; `copy`: the same, copied (for an app that does not follow links); `file`: PATH is one file, linked to the item a `use KIND NAME` line names |
| `FILES` | comma-separated, the first one the item has: `.` is the item folder itself (linked as `<item>`), a file name is that file (linked as `<item>` plus the file's extension: `claude.md` as `<item>.md`, `copilot.agent.md` as `<item>.agent.md`); an item with none of them is left out of this destination |
| `+HOOK` | `+claude-plugin-dirs`: sets `env.CLAUDE_CODE_PLUGIN_DIRS` of `~/.claude/settings.json` to the links, **joined with `:`** (Windows joins with `;`), then every entry added by hand, and runs `claude plugin validate` on each (a missing or rejecting CLI only warns); `+managed-settings`: makes the link through sudo |
| `PATH` | the rest of the line, spaces allowed; `~` and `$VARIABLES` expand |

A destination two harnesses name (Codex, Gemini CLI and Copilot all read `~/.agents/skills`) is
filled once. A destination no item goes to is never created. A fork defines any other app with
its own section in `ai-harnesses.local.conf`.

### The base catalogue

Each folder was checked against the app's own documentation (2026-10-25); the sources are listed
below the table. Claude Code's `~/.claude/commands` still works but its documentation now merges
custom commands into skills.

| Harness | Kind | Placement, files | macOS path |
| ------- | ---- | ---------------- | ---------- |
| `claude-code` | skills | each, `.` | `~/.claude/skills` |
| | mods | each, `.`, `+claude-plugin-dirs` | `~/.claude/mods` |
| | rules | file, `RULES.md` | `~/.claude/CLAUDE.md` |
| | rules | file, `managed-settings.json`, `+managed-settings` | `/Library/Application Support/ClaudeCode/managed-settings.json` |
| | prompts | each, `claude.md,PROMPT.md` | `~/.claude/commands` |
| | agents | each, `claude.md,AGENT.md` | `~/.claude/agents` |
| `codex` | skills | each, `.` | `~/.agents/skills` |
| | rules | file, `RULES.md` | `~/.codex/AGENTS.md` |
| | prompts | each, `codex.md,PROMPT.md` | `~/.codex/prompts` |
| | agents | each, `codex.toml` | `~/.codex/agents` |
| `gemini-cli` | skills | each, `.` | `~/.agents/skills` |
| | rules | file, `RULES.md` | `~/.gemini/GEMINI.md` |
| | prompts | each, `gemini.toml` | `~/.gemini/commands` |
| | agents | each, `gemini.md,AGENT.md` | `~/.gemini/agents` |
| `copilot` | skills | each, `.` | `~/.agents/skills` |
| | rules | file, `copilot.md,RULES.md` | `~/.copilot/copilot-instructions.md` |
| | agents | each, `copilot.agent.md` | `~/.copilot/agents` |

- Codex agents are TOML and Gemini CLI commands are TOML: only an item carrying that variant
  reaches them. Codex documents its custom prompts as deprecated in favour of skills.
- Copilot: the Copilot CLI's skill, instruction and agent folders. The CLI documents no prompt
  files, and VS Code's prompt folder lives in its profile, so the catalogue has no Copilot prompts.
  VS Code's Copilot also reads `~/.claude/skills` and `~/.agents/skills`, so with both
  `claude-code` and `copilot` on, it sees each skill twice.
- T3 Code has no section: it drives the agents installed on the Mac (Claude Code, Codex, ...),
  which read their own folders, so turning those on covers it.

Sources: Claude Code [skills](https://code.claude.com/docs/en/skills),
[.claude directory](https://code.claude.com/docs/en/claude-directory),
[managed settings](https://code.claude.com/docs/en/managed-settings) and
[environment variables](https://code.claude.com/docs/en/env-vars); Codex
[skills](https://learn.chatgpt.com/docs/build-skills),
[custom prompts](https://learn.chatgpt.com/docs/custom-prompts),
[AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md) and
[subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents); Gemini CLI
[skills](https://geminicli.com/docs/cli/skills/),
[custom commands](https://geminicli.com/docs/cli/custom-commands/),
[subagents](https://geminicli.com/docs/core/subagents/) and
[GEMINI.md](https://geminicli.com/docs/cli/gemini-md/); Copilot CLI
[skills](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/create-skills),
[custom agents](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/create-custom-agents-for-cli) and
[custom instructions](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions),
VS Code [agent skills](https://code.visualstudio.com/docs/copilot/customization/agent-skills);
[T3 Code](https://github.com/pingdotgg/t3code).

## Rules

A rules item is a folder `AI/Rules/<source>/<Name>/` with `RULES.md` (the instructions linked into
each app's global instruction file) and any per-app variants. Claude Code's managed settings, which
outrank every project and user setting, are the `managed-settings.json` variant: only the
`claude-code` harness takes it, through sudo (`+managed-settings`), so the AiArtifacts step shares
Bootstrap's one administrator prompt; without sudo that link is reported as skipped and the run
fails. A rules item without that file leaves the destination alone.

Only a `use rules NAME` line makes a `file` destination link anything, and the last one wins. The
base ships `AI/Rules/example/CoreAiRules/` (a skeleton: headings and one sample rule) and
`use rules CoreAiRules`; a fork writes its own `AI/Rules/own/CoreAiRules/`, which wins the name
clash, and silences the clash warning with `exclude rules/example/CoreAiRules`.

## Deploying

`Deploy-AiArtifacts` deploys, `--check` reports what a run would change. It is the Bootstrap step
`AiArtifacts`, off by default; `AiMarketplaces` and `AiMcpServers` (below) are their own steps. Turn them on in
`Unix/config/bootstrap.local.conf`:

```
step AiArtifacts on
step AiMarketplaces on
step AiMcpServers on
```

```bash
Bootstrap --only AiArtifacts AiMarketplaces AiMcpServers
```

Behaviour kept for every kind: a folder destination that is itself a link into the repository is
replaced by a real folder, one that links elsewhere (or a file in its place) is skipped; a real file
or folder where a link or copy goes is first copied into the backup sink (see
[Backups on a Mac](backups.md)), and when that copy fails the item is skipped and the run fails;
only dangling links that point into the artifacts root are pruned, a link to anything else is never
touched.

## Vendoring

A `[section]` of `ai-artifacts.conf` is one upstream repository, pinned to a commit, that can feed
several kinds:

```
[mattpocock]
repository  OWNER/skills
ref         main
skills      skills/engineering skills/productivity
```

`Update-AiArtifacts` downloads the pinned archive and copies the items found under each kind's
folders into `AI/<Kind>/<section>/`, writing an `UPSTREAM.md` per kind folder (the format WinuX's
`Update-AiArtifacts` writes) and the upstream license. The line kinds are on
[Configuration](configuration.md#ai-artifactsconf-and-ai-harnessesconf).

## Marketplaces

Marketplaces are not an artifact kind: their plugins install through Claude Code's own CLI.
`Deploy-AiMarketplaces` reads one `[section]` per marketplace from `Unix/config/ai-marketplaces.conf`
(the base file ships a commented example only; a fork's marketplaces go in
`ai-marketplaces.local.conf`):

```
[my-marketplace]
repository  MyOrg/MyMarketplace
plugins     my-plugin
env         CLAUDE_CODE_ENABLE_FUNCTION_HOOKS 1
option      my-plugin some-option true
```

It writes `extraKnownMarketplaces.<section>`, the `env` lines and `pluginConfigs.<plugin>@<section>`
into `~/.claude/settings.json`, then, with the `claude` CLI on PATH, adds every marketplace and
installs every plugin the CLI does not list yet. A `[plugin:NAME]` section configures a folder-loaded
mod under `pluginConfigs.<NAME>`. A plugin installed from a marketplace must not also be a vendored
mod: Claude Code would load it twice.

The Claude Code CLI is the `claude-code` cask (`brew install --cask claude-code`, a line of
`Brewfile.local`, see [Software on a Mac](software-list.md)).

## MCP servers

MCP servers are not an artifact kind either: Claude Code keeps them in `~/.claude.json`, Codex in `~/.codex/config.toml`, so they are written there rather than linked (the design is WinuX's [AI MCP Servers](https://ivanpavlak.github.io/WinuX/#/winux/ai/mcp-servers)). `Deploy-AiMcpServers` reads a `deploy` line and one `[section]` per server from `Unix/config/ai-mcp-servers.conf` (the base file ships a commented example only; a fork's servers go in `ai-mcp-servers.local.conf`):

```
deploy claude-code codex

[my-remote]
url               https://mcp.example.com/mcp

[my-keyed]
url               https://api.example.com/mcp
bearer-token-env  MY_API_KEY
```

It adds each server to Claude Code with `claude mcp add --scope user` (removing and adding again one `~/.claude.json` carries with another definition, leaving alone one it carries as configured) and writes each server's `[mcp_servers.<name>]` table into the Codex `config.toml`, every other line kept. A `bearer-token-env` line names the variable holding a key, so no secret is written; a server that signs in with OAuth needs `/mcp` in Claude Code and `codex mcp login <name>` once per machine. Servers are added and updated, never removed. The line kinds are on the [Deploy-AiMcpServers guide](guides/ai/Deploy-AiMcpServers.md).

## Verification (per machine, after enabling)

1. The three commands with `--check` end with a success line or name what is missing:

    ```bash
    Deploy-AiArtifacts --check
    Deploy-AiMarketplaces --check
    Deploy-AiMcpServers --check
    ```

2. `List-AiArtifacts --list-discrepancies` reports nothing: every item is deployed into every
   destination of the harnesses turned on.
3. The rules: `readlink ~/.claude/CLAUDE.md` and
   `readlink "/Library/Application Support/ClaudeCode/managed-settings.json"` print paths inside
   `AI/Rules/`.
4. The mods: `python3 -c 'import json,os; print(json.load(open(os.path.expanduser("~/.claude/settings.json")))["env"]["CLAUDE_CODE_PLUGIN_DIRS"])'`
   prints the links under `~/.claude/mods`, `:`-separated; `claude plugin validate ~/.claude/mods/<mod>` passes.
5. The marketplaces: `claude plugin marketplace list` names each configured marketplace and
   `claude plugin list` each of its plugins.
6. The MCP servers: `claude mcp list` names each configured server (one waiting for its OAuth sign-in says so) and `grep '^\[mcp_servers\.' ~/.codex/config.toml` each Codex table.
7. In a throwaway folder outside the repository, start a new session of each app (and restart the
   Claude desktop app for its Code tab) and confirm the skills (`/`), the mods, the plugins and the
   MCP servers' tools appear.

When one of these fails, see [Troubleshooting: AI](troubleshooting.md#ai).
