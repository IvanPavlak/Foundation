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
2. The checkout sources, in name order: a local repository linked in place (see
   [Checkout sources](#checkout-sources)).
3. `foundation` - the product skills Foundation ships: [foundation-configurator](foundation-configurator.md)
   and `document`, which turns a command's header into its module page entry and guide.
4. `example` - the example rules.
5. The vendored sources, in name order: a `[section]` of `ai-artifacts.conf` copied under
   `AI/<Kind>/<section>/` by [Update-AiArtifacts](modules/AI.md#update-aiartifacts).
6. The manifest sources: the rows of a manifest, linked from pinned clones in a cache (see
   [Manifest sources](#manifest-sources)); a row's source name is the owner of its upstream
   repository.

Any other source folder is not read: a repository that carries both halves keeps WinuX's product
skills in `AI/Skills/winux/`, which only Windows deploys. Leave an item out with an `exclude` line:
`exclude skills/tdd` drops it from every source, `exclude skills/foundation/document` from one.

## Profiles

An AI profile is what one machine runs: its rules, the Plan Claude Code must be signed in to, its
harnesses and artifacts, its MCP servers and marketplaces, and the repositories it owns. Each
machine runs exactly one. The profiles are the `[sections]` of `Unix/config/ai-profiles.conf`; the
base ships none, so profiles are off and every AI command behaves as without the file. A fork
writes its own in `ai-profiles.local.conf`:

```
host My-Work-Mac Work
default Personal
default-owner Personal
shared github.com/myuser/dotfiles

[Personal]
rules         Personal
plan          Max 00000000-0000-0000-0000-000000000000
unattended    on
autonomous    github.com/myuser/myproject

[Work]
rules         Work
plan          Team 11111111-1111-1111-1111-111111111111
mcp
exclude       skills/my-personal-skill
owns          github.com/my-org/*
```

Every AI command picks the profile once: `FOUNDATION_AI_PROFILE` (an override for one shell), then
the last `host NAME PROFILE` line naming this Mac's local hostname, then the last `default` line.
A machine type cannot pick it: the type is a layout choice. The `@TYPE` forms keep working inside
and outside the profiles.

| Line | Effect |
| ---- | ------ |
| `rules NAME` | the rules item the `file` destinations take; wins over `use rules` |
| `plan NAME UUID...` | the Plan: a display name and the organization UUID(s); the managed settings copy sets `forceLoginOrgUUID` to them (one as a string, several as an array). A `plan` line without a valid UUID fails closed: the copy is not rendered and the deployed one keeps its pin |
| `deploy HARNESS...` | the harnesses; wins over the `deploy` line of `ai-artifacts.conf` |
| `include KIND/NAME...` | a kind named here deploys only these items (`KIND/SOURCE/NAME` for one source's); a kind not named deploys all of its items |
| `exclude KIND/NAME...` | added to the `exclude` lines of `ai-artifacts.conf` |
| `mcp NAME...` | the MCP servers it registers (no line: all; a bare `mcp` line: none); see [MCP servers](#mcp-servers) |
| `marketplaces NAME...` | the marketplaces it installs (no line: all; a bare line: none) |
| `unattended on\|off` | whether unattended runs are allowed (default off); written into `ai-profile.conf` for the tools that run them |
| `owns PATTERN...` | the repositories it owns (the ownership guard refuses them to every other profile) |
| `policy LEVEL PATTERN...` | the repositories at a trust level; repeatable, the last matching line wins; see [Repository policies](#repository-policies) |
| `autonomous PATTERN...` | a synonym of `policy autonomous PATTERN...` |
| `default-policy LEVEL` | the level of every other repository, and of a folder without `origin` (default `branch`) |
| `merge-without-checks PATTERN...` | `autonomous` repositories that may merge a pull request with no CI check reported |
| `env NAME...` | the environment variables it needs, checked by `Initialize-AiProfile` |

Beside the profiles, `shared PATTERN...` names the repositories every profile may work on and
`default-owner PROFILE` the owner of a repository no pattern matches. A PATTERN is a shell glob on
the `origin` remote normalised to `host/owner/name`: lowercase, no scheme, no user, no `.git`
(`github.com/my-org/*`).

`Test-AiProfile` checks a machine: the profile and how it was picked, the expected and the
logged-in Plan, whether the deployed managed settings pin that Plan, every pay-per-use credential
(`ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `CLAUDE_CODE_OAUTH_TOKEN`, `apiKeyHelper`) and the
OAuth MCP servers that need their sign-in, and lists the [repository policy](#repository-policies) (never a mismatch); it exits 0 on a match, 1 on a mismatch and 2 without
profiles. `Initialize-AiProfile` walks the sign-ins once per machine (Claude Code, the GitHub CLI,
the OAuth MCP servers, the profile's environment variables) and ends with `Test-AiProfile`; every
sign-in happens in the tool itself, so no secret passes through Foundation. It is also the
Bootstrap step `AiProfileInit`, off by default and run right after `AiMcpServers`, so the Plan pin
is deployed before the login is checked: `step AiProfileInit on` in `bootstrap.local.conf` makes a
fresh Mac end its run signed in. The step waits at the terminal, so a run with it off stays
unattended and, with a profile active, only warns and names `Initialize-AiProfile`.

## Repository policies

A profile gives each repository it works on a trust level, and one hook enforces the level of the
repository a session works in. The levels are a closed set, from most to least trust:

| Level | Agents may | Agents may not |
| --- | --- | --- |
| `autonomous` | everything `branch` allows, plus `gh pr merge` when every CI check of the pull request passed | merge with a failing or pending check, or with no check reported (unless a `merge-without-checks` line names the repository) |
| `branch` | commit, push a non-default branch, open and ready pull requests | merge |
| `draft` | commit, push a non-default branch, open draft pull requests (`gh pr create --draft`) | `gh pr ready`, merge, a pull request without `--draft` |
| `readonly` | read, search and explain: the reading tools | any Bash or PowerShell call, and the Edit, Write, MultiEdit and NotebookEdit tools |
| `blocked` | nothing: the ownership guard refuses the prompt and every tool call | |

Every level keeps the always-denied list: a push to the default branch (an explicit
`master`/`main`/default refspec, or a plain push while it is checked out), a force push (`--force`,
`--force-with-lease`, `-f`, `+refspec`), deleting a branch, changing remotes, upstream tracking or
git configuration, and a branch cut from a remote branch without `--no-track`.

- `policy LEVEL PATTERN...` gives the repositories matching any PATTERN that level (patterns as
  for `owns`). `autonomous PATTERN...` is a synonym of `policy autonomous PATTERN...`, and both may
  be used. A level outside the set is warned about (`Deploy-AiArtifacts`, `Test-AiProfile`,
  `Test-ConfigurationSchema`) and its patterns skipped, so a typo cannot invent a looser level.
- Where lines of several levels match one repository, **the last matching line wins**: write the
  broad patterns first and the exceptions after them.
- `default-policy LEVEL` is the level of a repository no line matches, and of a folder outside any
  repository or without `origin`. Left out it is `branch`; a value that is not a level is warned
  about and becomes `readonly`.
- `merge-without-checks PATTERN...` lists `autonomous` repositories that may merge a pull request
  when `gh pr checks` reports no check at all. Left out, "no checks reported" is not green: a
  repository without CI never merges on its own. A failing or pending check refuses the merge
  everywhere.

The hook is `AI/Hooks/ai-repository-policy.sh`, one file for Foundation and WinuX (a `mirror` line
in both manifests), deployed next to the managed settings copy and wired into `PreToolUse` with
matcher `*`, so the file tools are stopped too. It runs under whichever `bash` Claude Code finds
(`/bin/bash` 3.2 included) with the system's BSD tools. It matches a command as a whole, with prose
taken out first: the body of a heredoc fed to `cat` or to a `-F -` option, and a quoted value with
whitespace given to a message option (`-m`, `--message`, `-t`, `--title`, `-b`, `--body`,
`--notes`, `--subject`, a PowerShell here-string included). A commit message that mentions
"configuration" or "git push --force" passes; `bash -c "..."` and a heredoc fed to a shell are
still matched, and a refspec or flag never holds whitespace, so nothing can be hidden that way. Any
review a merge also needs (a judge score, say) is the agent's own check, not the hook's.

**Unattended runs.** The launcher of an unattended run sets the `AI_UNATTENDED` environment
variable (`1`, `on`, `true` or `yes`). The ownership guard then refuses the run when the profile
has `unattended off` (or no `unattended` line), and in a repository at `draft` or `readonly`:
unattended work needs `autonomous` or `branch`. An attended session is not affected.

`Test-AiProfile` lists the default level, every `policy` and `autonomous` pattern with its level in
file order, and the `merge-without-checks` patterns; the list never changes its exit code.

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
| `+HOOK` | `+claude-plugin-dirs`: sets `env.CLAUDE_CODE_PLUGIN_DIRS` of `~/.claude/settings.json` to the links, **joined with `:`** (Windows joins with `;`), then every entry added by hand, and runs `claude plugin validate` on each (a missing or rejecting CLI only warns); `+managed-settings`: writes a root-owned rendered copy through sudo, never a link (see [Rules](#rules)) |
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
Bootstrap's one administrator prompt; without sudo it is reported as skipped and the run fails. A
rules item without that file leaves the destination alone.

The managed settings are a root-owned copy, never a link (a link into the repository would let
anything that can write the repository loosen the policy): `root:wheel`, mode 644, rewritten only
when the rendered content differs. Rendering replaces the token `{ManagedDir}` with the folder of
the destination (`/Library/Application Support/ClaudeCode`); with an AI profile it also sets
`forceLoginOrgUUID` from the profile's Plan, appends the ownership guard to
`hooks.UserPromptSubmit` and `hooks.PreToolUse` (matcher `*`) as
`bash "{ManagedDir}/ai-ownership-guard.sh" <Event>`, and appends the repository policy hook to
`hooks.PreToolUse` (matcher `*`) as `bash "{ManagedDir}/ai-repository-policy.sh"`. Next to it the
deploy writes the rules item's `hooks/` folder (as `hooks/`) and, with a profile, the engine's
`ai-ownership-guard.sh` and `ai-repository-policy.sh` (`AI/Hooks/`, mirror files WinuX ships at the
same paths) and `ai-profile.conf`:

```
# Written by Deploy-AiArtifacts from the AI profile configuration; do not edit.
profile Personal
default-owner Personal
unattended on
plan Max 00000000-0000-0000-0000-000000000000
shared github.com/myuser/dotfiles
owns Work github.com/my-org/*
autonomous github.com/myuser/myproject
default-policy branch
policy autonomous github.com/myuser/myproject
policy readonly github.com/myuser/archive-*
merge-without-checks github.com/myuser/myproject
```

The guard refuses a prompt or a tool call in a repository another profile owns (its `origin`
matched against `shared`, then `owns`, then `default-owner`); outside a repository it allows. The
`autonomous`, `default-policy`, `policy` and `merge-without-checks` lines are the active profile's
only: `default-policy` is always written (`branch` when unset, `readonly` when it names no level),
then one `policy LEVEL PATTERN` line per pattern in the file order of the profile (an `autonomous`
line as `policy autonomous`; a `policy` line naming no level is warned about and left out). The
`autonomous` lines stay first for a rules item's own hook that still reads them.

Only a `use rules NAME` line makes a `file` destination link anything, and the last one wins. The
base ships `AI/Rules/example/CoreAiRules/` (a skeleton: headings and one sample rule) and
`use rules CoreAiRules`; a fork writes its own `AI/Rules/own/CoreAiRules/`, which wins the name
clash, and silences the clash warning with `exclude rules/example/CoreAiRules`. With an AI profile,
its `rules NAME` line wins over the `use rules` line, so each profile can carry its own item.

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

## Checkout sources

A section with a `checkout PATH` line links the items of a local repository straight from its
working tree, never copied and without an `UPSTREAM.md`, so a pull of that repository updates them
at once:

```
[myskills]
checkout    $DEV/MySkills
skills      skills
```

The kind lines name the folders relative to PATH (`skills skills` without one); a skills folder
that holds no `SKILL.md` is looked into once, as a category level. A path that is not on this
machine is a warning and its items are skipped.

## Manifest sources

A section with a `manifest FILE` line reads a manifest: a UTF-8, tab-separated file with one
header row, `#` comment lines and blank lines ignored, and one row per item with these columns:

| Column | Meaning |
| ------ | ------- |
| `name` | the item's folder name in its source, and its installed name unless `rename=` gives another |
| `kind` | `skills`, `mods`, `rules`, `prompts` or `agents` |
| `scope` | `*` (every profile, and machines without profiles), profile names separated by commas, or `repo:<name>` for a repository-scoped item |
| `source` | `https://github.com/<owner>/<repo>` |
| `ref` | a full commit SHA, never a branch |
| `path` | the item's folder inside the source |
| `install` | `clone`, optionally followed by `rename=<new-name>` and/or `strip-invocation-guard` (removes `disable-model-invocation` from `SKILL.md`, so agents can call the skill) |

`Deploy-AiArtifacts` (so Bootstrap's AiArtifacts step on a fresh machine) and `Update-AiArtifacts NAME` clone each in-scope `source` at its `ref` once into
`~/.local/share/foundation/ai-manifests/<owner>/<repo>/<ref>/` (`$XDG_DATA_HOME` when set),
outside every repository, through git (only the pinned commit, a shallow fetch by id; the full clone
only when the server refuses that), so a private upstream uses git's own stored credentials; git's
prompt is off (`GIT_TERMINAL_PROMPT=0`), so one it cannot sign in to fails at once instead of
waiting, and each fetch is logged as it starts (`[NAME] fetching OWNER/REPO@REF`); a clone
already there is never fetched again, so a redeploy needs no network. `Deploy-AiArtifacts --check`
fetches nothing, and a row whose fetch fails is a warning: its item is left out until a later run
fetches it. A `strip-invocation-guard`
or a `rename=` row is linked from a derived copy, `<ref>.derived/<installed-name>/`, made next to
the clone: `disable-model-invocation` taken out of its `SKILL.md` frontmatter, and for a rename
`name:` set to the new name, since Claude Code names a skill by its frontmatter, not its folder. Only the rows
whose scope includes the active profile are deployed. A `repo:<name>` row is a skill linked into
that repository's `.claude/skills/` (the repository found by name in `repositories.conf`), and its
link name is added to the repository's `.git/info/exclude`, so nothing is committed.
`Update-AiArtifacts --check` reports every row whose upstream default branch has moved past its
pin and changes nothing; a row is updated by changing its `ref` in the manifest.

A section can be a checkout and a manifest source at once, the usual shape for a repository that
develops its own skills and pins third-party ones. A manifest row's source name is the owner of its
upstream repository, so `exclude skills/OWNER/NAME` leaves out exactly that row.

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

It adds each server to Claude Code with `claude mcp add --scope user` (removing and adding again one `~/.claude.json` carries with another definition, leaving alone one it carries as configured) and writes each server's `[mcp_servers.<name>]` table into the Codex `config.toml`, every other line kept. A `bearer-token-env` line names the variable holding a key, so no secret is written; a server that signs in with OAuth needs `/mcp` in Claude Code and `codex mcp login <name>` once per machine. Without an AI profile servers are added and updated, never removed. With one, its `mcp` lines pick the servers, `Deploy-AiMcpServers` records those it registered per app in `$XDG_STATE_HOME/foundation/ai-mcp-servers.state` and removes a recorded server the profile no longer lists; a configured server an app already carries exactly as configured counts as registered, and a server added any other way is never removed. The line kinds are on the [Deploy-AiMcpServers guide](guides/ai/Deploy-AiMcpServers.md).

## Verification (per machine, after enabling)

1. The three commands with `--check` end with a success line or name what is missing:

    ```bash
    Deploy-AiArtifacts --check
    Deploy-AiMarketplaces --check
    Deploy-AiMcpServers --check
    ```

2. `List-AiArtifacts --list-discrepancies` reports nothing: every item is deployed into every
   destination of the harnesses turned on.
3. The rules: `readlink ~/.claude/CLAUDE.md` prints a path inside `AI/Rules/`;
   `ls -l "/Library/Application Support/ClaudeCode/"` shows `managed-settings.json` (and, with a
   profile, `ai-ownership-guard.sh`, `ai-repository-policy.sh` and `ai-profile.conf`) as real
   files owned by `root`; with a profile, `Test-AiProfile` lists the [repository policy](#repository-policies).
4. The mods: `python3 -c 'import json,os; print(json.load(open(os.path.expanduser("~/.claude/settings.json")))["env"]["CLAUDE_CODE_PLUGIN_DIRS"])'`
   prints the links under `~/.claude/mods`, `:`-separated; `claude plugin validate ~/.claude/mods/<mod>` passes.
5. The marketplaces: `claude plugin marketplace list` names each configured marketplace and
   `claude plugin list` each of its plugins.
6. The MCP servers: `claude mcp list` names each configured server (one waiting for its OAuth sign-in says so) and `grep '^\[mcp_servers\.' ~/.codex/config.toml` each Codex table.
7. With AI profiles: `Test-AiProfile` exits 0 and names the expected profile and Plan.
8. In a throwaway folder outside the repository, start a new session of each app (and restart the
   Claude desktop app for its Code tab) and confirm the skills (`/`), the mods, the plugins and the
   MCP servers' tools appear.

When one of these fails, see [Troubleshooting: AI](troubleshooting.md#ai).
