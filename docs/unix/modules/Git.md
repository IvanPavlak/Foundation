<!-- reference: module unix Git -->

# Git

Git shorthands and repository cloning and updating.

Manifest: [`Unix/modules/Git/module.conf`](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Git/module.conf). One entry per command, alphabetical; the bullet block right under each heading is the parsed part.


`git-obsidian` (a POSIX helper of this module, the Git-Obsidian of Windows) commits and pushes the
**vault** repository - the notes. The vault's `.obsidian` settings are not in it: `.obsidian` is a
symlink into `Dotfiles/Obsidian/.obsidian` (the `settings` line of `obsidian.conf`, linked by
Bootstrap's ObsidianSettings step), so settings changes are committed with Dotfiles.
It runs in its own process, so the shell always stays in the folder it was called from: there is
no `end-location` setting like the Windows `Obsidian.GitEndLocation`. A vault that is not set,
missing or not a git repository stops it before any git command; `git-obsidian --help` (or `-h`)
only prints its usage, and any other argument is refused, so neither commits nor pushes.

## [Git-Diff](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Git/bin/Git-Diff)

- **Description:** `git diff HEAD`.
- **Usage:** `Git-Diff`
- **Alias:** `gdf`

## [GitBranch](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Git/bin/GitBranch)

- **Description:** Lists all branches with their last commit, or creates BRANCH. The Windows `-BranchName` names the branch too; a flag it does not know is an error.
- **Usage:** `GitBranch [BRANCH | --branch-name BRANCH]`
- **Alias:** `gb`

## [GitBranchDeleteAndPrune](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Git/bin/GitBranchDeleteAndPrune)

- **Description:** Force-deletes a local branch and prunes stale `origin` refs. The Windows `-BranchName` names the branch too; a flag it does not know (`-WhatIf` included) is an error and nothing is deleted.
- **Usage:** `GitBranchDeleteAndPrune BRANCH | --branch-name BRANCH`
- **Alias:** `gbd`

## [GitMergeM](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Git/bin/GitMergeM)

- **Description:** Merges master (or main) into the current branch.
- **Usage:** `GitMergeM`
- **Alias:** `gmm`

## [GitPull](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Git/bin/GitPull)

- **Description:** `git pull`, arguments passed through.
- **Usage:** `GitPull [ARGS...]`
- **Alias:** `gp`

## [GitStatus](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Git/bin/GitStatus)

- **Description:** `git status` with the `status-arguments` of `git.conf` (the Windows `GitStatusArguments`; `--short` without a line, a bare `status-arguments` line runs a plain `git status`, `@TYPE` per machine type). Arguments given on the call replace the configured ones entirely, as on Windows: `gs -v -v -u` shows the full diff of staged changes and every untracked file.
- **Usage:** `GitStatus [ARGS...]`
- **Alias:** `gs`

## [GitSwitch](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Git/bin/GitSwitch)

- **Description:** Switches to BRANCH, or to master/main when none is given. Only local branches count, as on Windows: a branch that exists only on `origin` is refused (`Branch 'NAME' does not exist!`), never created as a tracking branch. The Windows `-BranchName` names the branch too; a flag it does not know is an error.
- **Usage:** `GitSwitch [BRANCH | --branch-name BRANCH]`
- **Alias:** `gsw`

## [Initialize-Repository](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Git/bin/Initialize-Repository)

- **Description:** Clones URL into DIR; when DIR already is a checkout, updates it the way Update-Repositories does (local changes stashed and restored exactly, fast-forward only, never over an ignored file, nothing done that cannot be done without loss) instead of a plain `git pull`. `--archive` clones without history. A URL that a repository line of `repositories.conf` marks `shallow` is cloned `--depth 1` and keeps its `.git` (the Windows rule for the Obsidian repository, as a setting). Credentials stay with git's credential helper: `--token` (the Windows `-Token`) takes its value, warns that it is not used and goes on, so the Windows call shape clones into `--local-path`. Any other flag, or a third path, fails before anything is cloned.
- **Usage:** `Initialize-Repository URL|--repository-url URL DIR|--local-path DIR [--archive] [--token TOKEN]`

## [Invoke-StartupRepositoryUpdate](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Git/bin/Invoke-StartupRepositoryUpdate)

- **Description:** Updates the repositories of `startup-scope` (`All`, or group names; `@TYPE` lines per machine type; without a line for this machine type the `repository-scope` of `bootstrap.conf`, then `All`, as Windows falls back to `BootstrapConfig.RepositoryUpdateScope`) with `Update-Repositories --group GROUP... --no-clone --quiet` (`--all` for `All`); the scope names groups only, as on Windows, so a name that is no group (a repository name included) is reported and nothing is updated. It runs once a day with `startup-schedule daily` (the default; the day starts at `startup-day-start-hour`, default 6, and an hour outside 0-23 is 6 without a warning, as on Windows) or at most once per `startup-interval-hours` (whole hours, default 24, anything else 24) with `startup-schedule interval`. Off unless `repositories.conf` says `startup on`; the shared shell rc runs it after the greeting (not in tabs a workspace open spawns, and not with `FOUNDATION_STARTUP_SKIP=RepositoryUpdate`) and, on the daily schedule, at the first prompt after the day starts in a shell that was already open - a Mac woken from sleep. On every exit it records when the next run is due in `Unix/logs/.next-repository-update` (`EPOCH SCHEDULE`), which the shell rc reads with a builtin, so starting a shell or drawing a prompt runs nothing until a run is due. The stamp `Unix/logs/.last-repository-update` is written before the update; several shells started together run it once (the atomically created lock folder `Unix/logs/.repository-update.lock` holds the owner's process id, and a lock whose owner is gone is cleared). Never clones. `--force` runs it now, enabled or not
- **Usage:** `Invoke-StartupRepositoryUpdate [--force]`

## [Merge-Upstream](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Git/bin/Merge-Upstream)

- **Description:** Fetches REMOTE and merges REMOTE/BRANCH (default: the remote's HEAD branch, then `master`, then `main`) into the current branch of the repository (`$DOTFILES_ROOT`, from any folder) and stops before the commit: the merge is left staged and you commit it. It refuses to start with uncommitted changes to tracked files or a merge in progress, and an upstream that shares no history with the branch is refused with the one-time bridge to run (`git merge -s ours --allow-unrelated-histories`). `--owned-only`, or an `owned-only REMOTE` line of `upstream.conf`, takes only the paths of its `own` lines: every other path the merge changed is put back as HEAD has it and one the upstream added there is unstaged and removed, so a fork of WinuX and Foundation takes each half from its own upstream; a conflict outside the owned paths is resolved that way too. It then lists what it took back, warns about a `mirror` file among them (a WinuX file the fork takes from WinuX), and names the conflicts left. `--all-paths` takes every path for one run even when `upstream.conf` names the remote. `--dry-run` (the Windows `-WhatIf`) fetches and lists what would be taken and taken back, merging nothing. Exit status 1 when conflicts are left or it could not start; `git merge --abort` undoes a staged merge. Never adds a remote, commits or pushes.
- **Usage:** `Merge-Upstream REMOTE [--branch BRANCH] [--owned-only | --all-paths] [--dry-run]`

See [Fork Model](../fork-model.md) for the two-upstream setup it serves.

## [Test-GitRepository](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Git/bin/Test-GitRepository)

- **Description:** Tells whether a path (default: the current directory) is inside a git repository by walking up for a `.git` entry - the directory of a clone or the file of a worktree or submodule - without running git; a path that does not exist is not an error. Exit status 0 with the repository root on stdout, 1 outside; `--quiet` prints nothing
- **Usage:** `Test-GitRepository [PATH] [--quiet]` (the Windows-style `--path PATH` works too)

## [Update-Repositories](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Git/bin/Update-Repositories)

- **Description:** Clones missing repositories and updates existing ones from `Unix/config/repositories.conf`, by group or repository name, `--all`, or a menu (a flat list of the groups, then the repositories, where Windows nests them), without ever losing or misplacing local work (`Unix/lib/repository.sh`, the port of the Windows `Update-Repository`): a path that is not the top of its own repository, a merge, rebase, cherry-pick, revert or bisect in progress, unresolved conflicts or a detached HEAD are left alone; local changes, untracked files included, are stashed, tracked by commit and restored exactly, staged ones staged again, and a stash that cannot be restored cleanly is kept and named; the branch is fetched and only fast-forwarded (`git merge --ff-only --no-overwrite-ignore`), never over an ignored local file; a branch origin does not have and an unreachable origin are reported, not pulled. `--include-default-branch` (default from `include-default-branch` in the file, `--no-include-default-branch` turns it off for one run) also fast-forwards each default branch while another branch is checked out (`git fetch origin <default>:<default>`, never touching the working tree; `default-branch` or `origin/HEAD` names it), leaving one with local commits untouched. `--no-clone` reports missing repositories as skipped; every repository is printed under the name of its URL, like Get-RepositoryName on Windows (`/Owner/My_Repo.git` is `[My_Repo]`, whatever the entry is called); `--quiet` prints one line per repository (`[MyRepo] feature/login - updated, master fast-forwarded`) with no blank lines between the lines of a group, a heading per group when several run, and a totals line whose counts are colored like Windows (updated blue, up to date green, need attention red, skipped yellow); `--archive` writes history-less copies (shallow clone, `.git` removed) to `~/Desktop/<name>`, never the configured path, and skips every one whose folder already exists, leaving it out of the totals (a warning, none with `--quiet`), like the Windows archive mode; `--in-current-directory` (Windows `-InCurrentDirectory`) clones and updates in `./<name>` instead of the configured paths, and with `--archive` puts the copies there instead of the Desktop. A bare name matches a group first, then a repository, and an unknown one is reported while the others run; `--group` (Windows `-Group`) takes group names only and one that is no group aborts the call with the configured groups, nothing updated; `--repositories` (Windows `-Repositories`) takes repository names only, so a repository named like a group can be picked; `--repository-url URL --local-path DIR` (the Windows custom mode) clones or updates one repository outside the file. `--all`, `--group`, `--repositories` and the URL/path pair are separate modes, as the Windows parameter sets. Repositories run in file order and each folder once: a repository listed in two groups runs once, two entries that only share a name both run. A repository line ending in `shallow` is cloned `--depth 1`, keeping its `.git` (the Windows Obsidian rule as a setting). Exit status 1 when a repository needs attention. A flag it does not know is an error and nothing is updated.
- **Usage:** `Update-Repositories [GROUP|NAME[,...]...] [--all] [--archive] [--in-current-directory] [--no-clone] [--quiet] [--include-default-branch | --no-include-default-branch]`; `Update-Repositories --group GROUP[,...]... | --repositories NAME[,...]... [OPTIONS]`; `Update-Repositories --repository-url URL --local-path DIR [OPTIONS]`
