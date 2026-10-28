---
description: "Use when writing, modifying, or reviewing Foundation commands, libraries, shell rc files, bats suites, or Unix/config files."
applyTo: "Unix/**"
---

# Shell Conventions

Read and follow these files before generating or modifying anything under `Unix/`:

- `AI/Context/UNIX_CONTEXT.md` - the layout, a command's shape, the configuration model, the tests
- `AI/Instructions/ShellConventions.md` - language, commands, drivers, configuration, tests and
  documentation rules; it binds every change

**Never use em-dashes** (the em-dash character, U+2014) in code, comments, help text, strings or
messages; always use a plain hyphen `-`. The sole exception is the browser-title class of the title
patterns in `Unix/config/layouts/*`.

A change to a command updates its entry on `docs/foundation/modules/<Module>.md`, its `module.conf`
line, its guide under `docs/foundation/guides/<module>/` and its suite in the same change. Do not run
the suites yourself: hand the developer the `Run-Tests` command that covers the change.

## CRITICAL SAFETY - Never Act Destructively On Your Own

You are NEVER allowed to commit, push, or perform ANY destructive or irreversible operation on your own initiative - EVER. Each such action requires an explicit, in-the-moment instruction from the user for that specific action. General prior approval, "continue", "do everything", or your own judgment do NOT count as permission.

Never do these without the user explicitly asking for that exact action in the current turn:

- `git commit`, `git push`, `git reset`, `git rebase`, `git branch -D`, `git checkout -- <file>`, tag or force operations, or anything that writes to git history or a remote
- Deleting or overwriting files/directories the user did not ask you to change (`rm`, mass overwrites)
- Creating a branch that tracks a remote branch under a different name (`git switch -c <branch> origin/master` does; use `--no-track`), or changing upstream tracking, remotes, or git configuration - a branch tracking the default branch sends the next plain `git push` straight onto it, skipping the PR
- Restructuring or moving core folders, or any other hard-to-reverse change

If such an action seems warranted, STOP and ask first, stating exactly what you intend to do, and wait for explicit confirmation. Default to the least destructive path. Creating/editing files for the task at hand and running read-only/verification commands are fine.

See `AGENTS.md` for the full critical operations policy.
