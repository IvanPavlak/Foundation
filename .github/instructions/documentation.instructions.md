---
description: "Use when writing, updating, or generating documentation pages, sidebar navigation, configuration guides, or cross-references in the Docsify documentation site."
applyTo: "docs/**"
---

# Documentation Conventions

Read and follow the Documentation section of `AI/Instructions/ShellConventions.md` before
generating or modifying documentation, and `AI/Context/UNIX_CONTEXT.md` for the system the pages
describe.

- The docsify pages under `docs/foundation/` are the single source of truth. `README.md` at the
  repository root is a short pointer to them and carries no command reference.
- One man-style entry per command on `docs/foundation/modules/<Module>.md`: a `## [Name](source URL)`
  heading followed at once by the `- **Description:**`, `- **Usage:**` and (when there is one)
  `- **Alias:**` bullets; alphabetical. `List-Functions --list-discrepancies` parses them.
- Every command has exactly one guide, `docs/foundation/guides/<module>/<Command>.md`: the FULL template
  when it reads a `Unix/config` file, the STUB template otherwise (both in
  `docs/foundation/guides/README.md`), listed in that folder's `README.md`.
- A page added or removed updates `docs/foundation/_sidebar.md` and `docs/foundation/docs_overview.md`.
- Links inside `docs/foundation` are relative and checked by `Unix/tests/doclinks.bats`; a link to a
  WinuX page is absolute (`https://ivanpavlak.github.io/WinuX/#/...`).
- Generic example values only (`MyProject`, `MyRepo`, `My-Mac`, `you@example.com`) - no real
  personal identifiers.
- Never use em-dashes (the em-dash character, U+2014); always a plain hyphen `-`.

## CRITICAL SAFETY - Never Act Destructively On Your Own

You are NEVER allowed to commit, push, or perform ANY destructive or irreversible operation on your own initiative - EVER. Each such action requires an explicit, in-the-moment instruction from the user for that specific action. General prior approval, "continue", "do everything", or your own judgment do NOT count as permission.

Never do these without the user explicitly asking for that exact action in the current turn:

- `git commit`, `git push`, `git reset`, `git rebase`, `git branch -D`, `git checkout -- <file>`, tag or force operations, or anything that writes to git history or a remote
- Deleting or overwriting files/directories the user did not ask you to change (`rm`, mass overwrites)
- Creating a branch that tracks a remote branch under a different name (`git switch -c <branch> origin/master` does; use `--no-track`), or changing upstream tracking, remotes, or git configuration - a branch tracking the default branch sends the next plain `git push` straight onto it, skipping the PR
- Restructuring or moving core folders, or any other hard-to-reverse change

If such an action seems warranted, STOP and ask first, stating exactly what you intend to do, and wait for explicit confirmation. Default to the least destructive path. Creating/editing files for the task at hand and running read-only/verification commands are fine.

See `AGENTS.md` for the full critical operations policy.
