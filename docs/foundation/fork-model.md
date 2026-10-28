# Fork Model

Foundation is meant to be **forked**, as WinuX is: the engine, the commands and the docs have one
home everyone improves, and your machine's values stay yours. This page is the Foundation version
of WinuX's [Fork Model](https://ivanpavlak.github.io/WinuX/#/winux/contributing/fork-model); it adds
what a fork of **both** WinuX and Foundation needs.

## The idea

- **Foundation (upstream)** is the single source of truth for `Unix/`, `docs/foundation/` and the generic
  base files under `Unix/config`.
- **Your fork** is a normal git fork. You merge improvements from upstream like any fork.
- **Your values** live in the `.local` overlays next to the base files. The base files are never
  edited with personal values, so a merge from upstream never conflicts on configuration.

```
Foundation (upstream)            your fork
─────────────────────            ─────────────────────────────────────────
Unix/config/NAME.conf  ──merge──► Unix/config/NAME.conf        (tracks upstream, unchanged)
                                  Unix/config/NAME.local.conf  (yours)
                                            │
                                   layered at read time
                                            ▼
                                   effective configuration
```

## Your values: the `.local` overlays

| What | Base (upstream) | Yours |
| --- | --- | --- |
| Settings, workspaces, projects, repositories, ... | `Unix/config/NAME.conf` | `Unix/config/NAME.local.conf` |
| A layout of a shipped set | `Unix/config/layouts/<Type>/<Workspace>_<Type>.conf` | `<Workspace>_<Type>.local.conf` next to it, or a set folder of your own (`layouts/Work/`) |
| Packages | `Unix/Brewfile` (what Foundation needs) | `Unix/Brewfile.local`, bundled after it |

An overlay adds lines before the first section, replaces a `[Section]` whole, takes a base line
back with `-LINE`, and limits any line to machine types with `@TYPE`. The full rules and what each
base file ships are on [Configuration](configuration.md#base-and-overlay). You rarely write them by
hand: Initialize-Configuration (the first Bootstrap step), the `Add-*` commands and the
[FoundationConfigurator](foundation-configurator.md) write the overlays, never the base.

### One machine vs. several

Foundation's `.gitignore` ignores every overlay, which suits a single machine: nothing personal can
reach a public fork. To share your values between Macs, commit them in your fork with
`git add -f` (upstream never ships those files, so a merge never conflicts on them) and key what
differs per machine with `@TYPE` lines and `machines.conf`.

## Your payload files

The two terminals take an override file of yours next to their shared config, so you never edit
the shared file: `WezTerm/wezterm.local.lua` returns a function that changes the config
(`return function(config, wezterm) config.font_size = 14.0 end`), and `Unix/ghostty/config.local`
holds Ghostty lines. Both load last, so their values win; chezmoi links each next to its shared
config only when your repository has it, and Foundation's `.gitignore` ignores both (commit them
with `git add -f`).

Two files have no override because their tool reads one file whole:
`Unix/aerospace/aerospace.toml` and `Btop/Unix/btop.conf` (btop also rewrites its own). Foundation
ships sensible defaults; edit your fork's copies in place. Foundation's `.gitattributes` marks both
`merge=ours`, so a merge keeps your edited copy. Git runs that driver only once it is
registered; Foundation's git overrides (`Git/Unix/gitconfig.local`, linked to `~/.gitconfig.local`
by chezmoi) register it, so a bootstrapped Mac needs nothing more.

`merge=ours` only acts when both sides changed the file: a payload you have edited keeps your copy,
one you never edited follows upstream. An upstream change to a payload you edited is never taken;
diff it against upstream and port what you want by hand.

## Your commands: the Custom area

Commands Foundation does not ship live in `Unix/modules/Custom/<Module>/bin`, with their pages in
`docs/foundation/custom/<module>.md` and their suites in `Unix/tests/modules/Custom/<Module>/`. Upstream
ships the area empty and never writes inside it, so it never conflicts. See
[Custom Area](custom/README.md).

## Setting up your fork

1. Fork Foundation on GitHub and clone your fork.
2. Add the upstream remote, named after the project:

    ```bash
    git remote add foundation https://github.com/IvanPavlak/Foundation.git
    ```

3. Run `Unix/bootstrap.sh` (see [Bootstrap a Mac](bootstrap.md)); Initialize-Configuration writes
   your first overlays.
4. Put your packages in `Unix/Brewfile.local`, never in `Unix/Brewfile`.

A private fork runs no workflow at all: every job of every upstream's workflows is skipped in a
private repository, so no Actions minutes are spent on it. Run `Run-Tests` locally instead; the public
upstreams run the same suites on every pull request.

## Rooms, mirror and hallway

A fork can merge more than one project into the same repository: Foundation for the Mac, WinuX for
Windows, or any later project built the same way. Think of the repository as a house. Each project
is a tenant with **rooms** only it ever writes; the **hallway** is everything else, the files at the
root that GitHub, git and the editors look for. Each project ships a **manifest** listing its rooms,
Foundation's is `Unix/config/upstream.conf`:

```conf
name        foundation
url         https://github.com/IvanPavlak/Foundation.git
tag-prefix  foundation
changelog   Unix/CHANGELOG.md
own         Unix/
own         docs/foundation/
own         .github/workflows/foundation.yml
mirror      LICENSE
mirror      Git/.gitconfig
```

(abridged; the [configuration page](configuration.md#upstreamconf) has the format). On a merge from
one project, `Merge-Upstreams` handles every changed path by exactly one rule, the first that
matches:

| The path is | Example | What happens |
| --- | --- | --- |
| in another project's rooms (its `own` lines) | `Windows/...` in a Foundation merge | Declined: only that project writes there. |
| in this project's rooms (`own`) | `Unix/modules/Git/...`, `docs/foundation/modules/Git.md` | Always taken, exactly as the project has it. Every file of a project lives in its rooms, so nothing of it is ever lost. |
| adopted by a `take` line of the fork | `take foundation .github/ISSUE_TEMPLATE/` | Taken, as if it were the project's room. |
| a `mirror` file, byte-identical in every project by contract | `LICENSE`, `CODE_OF_CONDUCT.md`, `Git/.gitconfig` | Taken from any project; the same bytes arrive either way. |
| in the hallway (anything else) | `README.md`, `.github/PULL_REQUEST_TEMPLATE.md`, `.gitignore` | Taken when this project is the **root owner**, declined otherwise. |

Declining deletes nothing: the path is put back as your branch has it (a path your branch does not
have is unstaged and removed, with its empty folders), and every declined path is listed. Any
declined file is one command away: `git show foundation/master:README.md`.

Foundation's project documents (`CHANGELOG.md`, `VERSIONING.md`, `CONTRIBUTING.md`, `SECURITY.md`,
`AGENTS.md`, `CONTEXT.md`, `NOTICE`, `THIRD-PARTY-LICENSES.md`) live in its room, `Unix/`. The
files of those names at the root are generic pointers, the same bytes in every project, so they
never conflict.

### Who owns the root

`root-owner` decides the hallway. Without a setting it is the only upstream your repository knows
(a plain fork of Foundation keeps receiving the README it forked), and `fork` when it knows several
(between two projects' READMEs there is no right answer, so neither overwrites yours). You can set
it, and adopt single hallway paths from one project, in the optional settings file
`Git/upstreams.local.conf`, which no project ships:

```conf
# root-owner NAME|fork: who owns the hallway (default: the only upstream, else fork)
root-owner fork
# take UPSTREAM PATH: adopt a hallway path (a PATH ending in / covers everything under it)
take foundation .github/ISSUE_TEMPLATE/
```

An upstream that adds a new hallway file under `fork` has it declined and listed; a `take` line
adopts it if you want it.

### Fixed-path hallway files

Some hallway files cannot move into a project's room, because a tool reads them at a fixed path:

| File | Why it stays at that path |
| --- | --- |
| `README.md` | GitHub's landing page for the repository |
| `AGENTS.md` | Codex and Gemini read it from the repository root (the root one points at every `*/AGENTS.md`) |
| `.github/ISSUE_TEMPLATE/*`, `.github/PULL_REQUEST_TEMPLATE.md`, `.github/FUNDING.yml`, `.github/rulesets/*`, `.github/instructions/*` | GitHub and Copilot conventions: read only from `.github/` |
| `.gitattributes`, `.gitignore` | git reads them from the repository root only (as the root file) |
| `.vscode/*` | VS Code reads the workspace root's `.vscode/` |
| `docs/index.html`, `docs/README.md`, `docs/_sidebar.md`, `docs/.nojekyll` | the docsify site root on GitHub Pages |

`docs/index.html` is the same generic shell in every project; the docs landing (`docs/README.md`,
`docs/_sidebar.md`) lists the projects. Each project's pages live in its own docs folder
(`docs/foundation/`, `docs/winux/`) with its own sidebar, so they arrive with every merge.

## Tags and remotes

Each project tags its releases under its prefix in its own repository: `foundation/v0.2.0`,
`winux/v2.0.0`. Tags of two projects never clash, so a plain `git fetch` needs no `--no-tags`, no
tag refspec and no per-clone setting, and `Merge-Upstreams` fetches exactly the prefixed tags of the
project it merges. The remote of a project is named after it (`foundation`, `winux`), but the
command finds it by its URL first, so an older name keeps working until you rename it.

## One-time setup

The command never writes git config; it prints what to run. In a fork of Foundation alone:

```bash
git remote add foundation https://github.com/IvanPavlak/Foundation.git
```

A clone set up before the prefixed tags used other names and a tag refspec. Rename the remotes
once and drop the old tag settings (and the bare tag copies they made, which come back prefixed):

```bash
git remote rename macupstream foundation
git remote rename upstream winux
```

```bash
git config --unset remote.foundation.tagOpt
git config --unset-all remote.foundation.fetch '^\+refs/tags/'
git config --unset remote.winux.tagOpt
git config --unset-all remote.winux.fetch '^\+refs/tags/'
```

A repository that shares no history with a project yet (a fork of WinuX adding Foundation) bridges
it once; `Merge-Upstreams` prints this command when it is needed:

```bash
git merge -s ours --allow-unrelated-histories -m "Bridge foundation as an upstream" foundation/master
```

The bridge changes no file (`git diff HEAD~1 HEAD` is empty); it gives the histories a common
commit, so later merges see only what the project changed since.

## Merging upstream updates

```bash
Merge-Upstreams foundation --dry-run
```

```bash
Merge-Upstreams foundation
```

The dry run fetches and computes the same merge with `git merge-tree` (git 2.38 or newer), touching
neither your index nor your working tree, so it lists exactly what the real run would take per rule,
put back and stop on as a conflict, and every `mirror` file whose merged copy would differ from the
project's (a broken contract: take it from the project that is right), merging nothing. The real run leaves the merge staged, never committed:
review it with `git diff --cached`, then commit it with the message it suggests (`Merge foundation
master: 0.2.0`, the newest release of the project's changelog) and push it with the command it
prints (on `master` it first branches off, `git switch -c merge-foundation`, so the merge goes
through a pull request). Conflicts left in taken paths are listed; resolve them and commit, or undo
everything with `git merge --abort`. See [Merge-Upstreams](modules/Git.md#merge-upstreams).

## Two worked configurations

### A plain fork of Foundation

Nothing to configure. The repository knows one upstream, so Foundation owns the root: its README,
`.github/` templates and docs landing keep arriving with every merge, as in any fork.

```bash
git remote add foundation https://github.com/IvanPavlak/Foundation.git
Merge-Upstreams foundation
```

### A fork of WinuX and Foundation with its own root

The repository holds both manifests (`Windows/PowerShell/Upstream.conf` and
`Unix/config/upstream.conf`), so the root owner is `fork` without any setting: `Windows/` and
`docs/winux/` come from WinuX, `Unix/` and `docs/foundation/` from Foundation, the `mirror` files
from either, and the README, `.github/` and docs landing are yours. Write a short root `README.md`
and a docs landing listing `winux/` and `foundation/` once. To adopt a project's issue templates:

```conf
# Git/upstreams.local.conf
take winux .github/ISSUE_TEMPLATE/
```

Merge one upstream at a time, committing in between; the same commands work in PowerShell on
Windows (`Merge-Upstreams winux`), with the same staged result:

```bash
Merge-Upstreams winux
git commit -m "Merge winux master: 2.0.0"
Merge-Upstreams foundation
git commit -m "Merge foundation master: 0.2.0"
```

## Versions

Foundation's version says how much attention a merge needs (see
[Versioning](https://github.com/IvanPavlak/Foundation/blob/master/Unix/VERSIONING.md)). Before 1.0.0
any release may rename or remove a command, flag, config line kind or Bootstrap step, with a
migration note in `Unix/CHANGELOG.md`; read the notes of each release you merge. From 1.0.0 on,
WinuX's ladder applies: a MINOR only deprecates, keeping the old shape working, and removals wait
for a MAJOR.
