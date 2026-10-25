# AI Mods

Claude Code mods (function-hook plugins that draw bands, panes and status entries and hook engine
events), one kind of AI artifact, linked into `~/.claude/mods` and listed in the
`env.CLAUDE_CODE_PLUGIN_DIRS` key of `~/.claude/settings.json` by `Deploy-AiArtifacts` through the
`+claude-plugin-dirs` hook of the `claude-code` harness (opt-in: `step AiArtifacts on` in
`Unix/config/bootstrap.local.conf`). The mechanism: [AI on a Mac](../../docs/unix/ai.md).

Layout: one subfolder per source, each holding `<mod>/` folders. A folder is a mod when it holds
`.claude-plugin/plugin.json`; the rest of a mod is its hooks module (`hooks/hooks.json` naming
`hooks/register.tsx`) and, when it keeps values in `$.state`, its type contract
(`types/index.d.ts`).

- `own/` - your own mods (no manifest; never touched by a refresh).
- `<source>/` - an upstream vendored by `Update-AiArtifacts` from a `[source]` section of
  `ai-artifacts.conf` with mods, pinned to a commit; its `UPSTREAM.md` records the commit and lists
  every vendored mod, next to the upstream license. Never edit these folders by hand - change the
  mod upstream and run `Update-AiArtifacts` again.

Authoring a mod: load the `plugin-authoring` skill in Claude Code, which writes the engine's type
declarations and hot-reloads the mod while you work; check it with `claude plugin validate <folder>`.

Foundation ships only this file. Every source folder belongs to your fork.
