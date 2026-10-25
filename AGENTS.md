# Project Guidelines

## Repository Overview

Foundation is the macOS counterpart of WinuX: a dotfiles system of bash executables
(`Unix/modules/<Module>/bin`), sourced libraries (`Unix/lib`), small per-concern config files with
`.local.conf` overlays (`Unix/config`) and chezmoi link templates (`Unix/home`). The docsify docs
under `docs/unix/` are the single source of truth.

**Before working on any task**, read:

- `AI/Context/UNIX_CONTEXT.md` - the layout, a command's shape, the configuration model, the tests
- `AI/Instructions/ShellConventions.md` - how code, tests, docs and configuration are written; it
  binds every change

`CONTEXT.md` names the domain's seams (driver, base and overlay, machine type, workspace, layout,
Bootstrap step, path ownership).

## Rules that bind every change

- **Never use em-dashes**: always a plain hyphen `-` instead of the em-dash character (U+2014), in
  prose, comments, docs, messages, strings and commit messages. The sole exception is the
  browser-title class of the title patterns in `Unix/config/layouts/*` (see ShellConventions).
- **Docs in the same change.** A change that adds, removes or alters a command, a flag, a config
  line kind, a Bootstrap step, a package of the base `Unix/Brewfile` or a page updates its docs in
  the same change (the trigger list is the Documentation section of ShellConventions). A change to a
  documented surface without its page is incomplete.
- **No personal values in tracked base files.** Base config files, docs and guides ship generic
  values only (`MyProject`, `MyRepo`, `My-Mac`, `you@example.com`); `Unix/tests/vanilla.bats`
  checks the base config.
- **Before 1.0.0 no compatibility rules apply**, but every rename or removal carries a migration
  note in `CHANGELOG.md` (see `VERSIONING.md`).
- **Governance stays consistent.** A rule changed here or in `AI/Instructions/ShellConventions.md`
  is changed in the other surfaces that state it (`.github/instructions/`) in the same change.

## Running Tests (Delegate to the Developer)

Do NOT run the suites yourself. After you add or change commands, tests or docs, give the developer
the exact `Run-Tests` command in one line, say what it covers, and wait for their pass/fail report
before treating the change as verified:

- **Scoped (preferred):** `Run-Tests <Command>` - the suites whose path contains the pattern, once
  per changed area.
- **Repository coherence (commands, manifests, guides, docs links):** `Run-Tests commands guides doclinks`.
- **Whole suite (broad or cross-cutting changes):** `Run-Tests`.
- **Faster modes the developer may use:** `--changed` (only what the branch can affect) and
  `--quick` (no integration tier). Neither replaces the full run.
- **Diagnosing a failure:** the developer can paste the run log the verdict names
  (`Unix/tests/Results/TestRun_<timestamp>.log`).

Only run tests yourself if the developer explicitly asks you to.

## CRITICAL SAFETY - Never Act Destructively On Your Own

You are NEVER allowed to commit, push, or perform ANY destructive or irreversible operation on your own initiative - EVER. Each such action requires an explicit, in-the-moment instruction from the user for that specific action. General prior approval, "continue", "do everything", or your own judgment do NOT count as permission.

Never do these without the user explicitly asking for that exact action in the current turn:

- `git commit`, `git push`, `git reset`, `git rebase`, `git branch -D`, `git checkout -- <file>`, tag or force operations, or anything that writes to git history or a remote
- Deleting or overwriting files/directories the user did not ask you to change (`rm`, mass overwrites)
- Creating a branch that tracks a remote branch under a different name (`git switch -c <branch> origin/master` does; use `--no-track`), or changing upstream tracking, remotes, or git configuration - a branch tracking the default branch sends the next plain `git push` straight onto it, skipping the PR
- Restructuring or moving core folders, or any other hard-to-reverse change

If such an action seems warranted, STOP and ask first, stating exactly what you intend to do, and wait for explicit confirmation. Default to the least destructive path. Creating/editing files for the task at hand and running read-only/verification commands are fine.
