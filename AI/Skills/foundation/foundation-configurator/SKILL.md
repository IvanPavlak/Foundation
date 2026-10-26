---
name: foundation-configurator
description: Interview the user decision by decision and write their answers into the config files of Foundation, the macOS counterpart of WinuX (Unix/config - repositories, browser groups, projects, layouts, workspaces, machines, apps, and the Bootstrap provisioning files: bootstrap, system defaults, power, Dock, login items, dotnet, conda), with a backup before each file's first write and Test-ConfigurationSchema after. Use when the user wants to configure Foundation on a Mac, add a repository, project, browser group, layout or workspace to the Unix half, set up a new project end to end for w, choose which Bootstrap steps run on a Mac and what they set, or review what the Unix config holds.
argument-hint: "Everything, a config file name, a task such as 'add MyProject end to end' or 'provision this Mac', or 'review'"
---

The user wants the Unix half (Foundation) of their fork configured by interview. The protocol is not in this file: it lives in the repository, in `docs/unix/foundation-configurator.md`. Read it and run it.

## Step 1 - Locate the repository

This skill is linked into the harness's user-level skills directory, so the current working directory is almost never the checkout.

- The skill folder (`~/.claude/skills/foundation-configurator` or `~/.agents/skills/foundation-configurator`) is a symbolic link to `<RepoRoot>/AI/Skills/foundation/foundation-configurator/`. Resolve the link and take the folder three levels above it. With the WinuX shell loaded, `Get-RepositoryPath` answers directly.
- Confirm the result by checking that `<RepoRoot>/Unix/config/workspaces.conf` exists. If it does not, ask the user for the checkout path.
- Note whether `<RepoRoot>/Windows/PowerShell/Configuration.psd1` exists too. If it does, the checkout also holds WinuX, and the protocol's ground rule 8 has you write the Windows counterpart of every entry in the same session, under `docs/configuration/winux-configurator.md`.

## Step 2 - Read the protocol

Read `<RepoRoot>/docs/unix/foundation-configurator.md` in full before the first question. It carries the ground rules, the prerequisites, the modes, the walk order, the decisions per config file and the tasks. Read each config file's header comment before writing to it; the header is its format.

## Step 3 - Run the session

Follow the protocol's Session Protocol steps 0 through 4 in order. The session is done when every file in the chosen scope has been walked, written, backed up and checked with `Test-ConfigurationSchema --quiet` (plus, for a Bootstrap provisioning file, its own `--list` or `--dry-run` check from the protocol; in a checkout of both halves, its Windows counterparts written and their checks handed over), and the user has the closing summary plus the commands only they should run.
