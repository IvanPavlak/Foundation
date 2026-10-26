# AI Skills

Agent Skills, one kind of AI artifact, linked into the AI apps a Mac uses by `Deploy-AiArtifacts`
(opt-in: `step AiArtifacts on` in `Unix/config/bootstrap.local.conf`, the apps named by the `deploy`
line of `ai-artifacts.local.conf`). The mechanism: [AI on a Mac](../../docs/unix/ai.md).

Layout: one subfolder per source, each holding flat `<skill>/SKILL.md` folders. The sources are
read in this order, the first winning a name two of them carry:

- `own/` - your own skills (no manifest; never touched by a refresh). Foundation ships it empty.
- `foundation/` - the product skills Foundation ships: [foundation-configurator](foundation/foundation-configurator/SKILL.md),
  which runs the [FoundationConfigurator](../../docs/unix/foundation-configurator.md) interview, and
  [document](foundation/document/SKILL.md), which turns a command's header into its module page
  entry and configuration guide. Leave one out with `exclude skills/foundation/document`.
- `<source>/` - an upstream vendored by `Update-AiArtifacts` from a `[source]` section of
  `ai-artifacts.conf`; its `UPSTREAM.md` records the pinned commit and lists every vendored skill.

Any other folder is not read.
