# Fork Model

Foundation is meant to be **forked**, as WinuX is: the engine, the commands and the docs have one
home everyone improves, and your machine's values stay yours. This page is the Foundation version
of WinuX's [Fork Model](https://ivanpavlak.github.io/WinuX/#/contributing/fork-model); it adds
what a fork of **both** WinuX and Foundation needs.

## The idea

- **Foundation (upstream)** is the single source of truth for `Unix/`, `docs/unix/` and the generic
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
[macOS Configurator](macos-configurator.md) write the overlays, never the base.

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
`docs/unix/custom/<module>.md` and their suites in `Unix/tests/modules/Custom/<Module>/`. Upstream
ships the area empty and never writes inside it, so it never conflicts. See
[Custom Area](custom/README.md).

## Setting up your fork

1. Fork Foundation on GitHub and clone your fork.
2. Add the upstream remote:

    ```bash
    git remote add upstream https://github.com/IvanPavlak/Foundation.git
    ```

3. Run `Unix/bootstrap.sh` (see [Bootstrap a Mac](bootstrap.md)); Initialize-Configuration writes
   your first overlays.
4. Put your packages in `Unix/Brewfile.local`, never in `Unix/Brewfile`.

## Merging upstream updates

```bash
Merge-Upstream upstream
```

[Merge-Upstream](modules/Git.md#merge-upstream) fetches and merges `upstream/master`, stops before
the commit and names the conflicts left; review the staged merge with `git diff --cached` and
commit it yourself. A plain `git fetch upstream` and `git merge upstream/master` do the same.

## A fork of both WinuX and Foundation

A fork can hold both halves: WinuX's `Windows/` and the shared files from WinuX, `Unix/` and the
other Foundation paths from Foundation. Foundation mirrors WinuX's root layout, so the two trees fit
together path for path. Each path then has one upstream:

| Class | Paths | Taken from |
| --- | --- | --- |
| Foundation-owned | the `own` lines of `Unix/config/upstream.conf`: `Unix/`, `docs/unix/`, `.github/workflows/unix.yml`, `AI/Context/UNIX_CONTEXT.md`, `AI/Instructions/ShellConventions.md`, `AI/Skills/foundation/`, `AI/Rules/example/`, `FastFetch/Unix/`, `Git/Unix/`, `Btop/Unix/`, `Btop/themes/`, `WezTerm/` | Foundation |
| Mirrored | the `mirror` lines: WinuX files Foundation ships byte-identical and never edits (`LICENSE`, `Git/.gitconfig`, ...) | WinuX |
| Root files both ship | `README.md`, `CHANGELOG.md`, `AGENTS.md`, `.gitignore`, `.github/`, `docs/_sidebar.md`, ... | WinuX (Foundation's versions describe Foundation alone) |
| Everything else | `Windows/`, the WinuX docs, ... | WinuX |

### One-time setup

```bash
git remote add macupstream https://github.com/IvanPavlak/Foundation.git
```

```bash
git fetch macupstream
```

```bash
git merge -s ours --allow-unrelated-histories -m "Bridge Foundation as second upstream" macupstream/master
```

The bridge merge changes no file (`git diff HEAD~1 HEAD` is empty); it gives the two histories a
common commit, so later merges see only what Foundation changed since. Then name the remote in
`Unix/config/upstream.local.conf`, so every merge from it takes only Foundation's paths:

```conf
owned-only macupstream
```

### Every merge

```bash
Merge-Upstream upstream
```

```bash
Merge-Upstream macupstream
```

The WinuX merge is a plain one. The Foundation merge is owned-only: every path outside the `own`
lines that it changed is put back as your branch has it, a path it added there is unstaged and
removed, and a conflict there is resolved the same way. It lists what it took back and warns about
a mirrored file among them, which you take from WinuX instead. `Merge-Upstream macupstream
--dry-run` shows the split before anything is merged.

Two things never arrive by themselves: a Foundation page added to its own `docs/_sidebar.md` (yours
is WinuX's; the Foundation pages have their own sidebar, `docs/unix/_sidebar.md`, which does
arrive), and a change to a root file both ship. Read the taken-back list after each Foundation
merge and port what you want by hand.

On a machine without Foundation's commands (Windows), the owned-only merge is a short recipe:

```bash
git fetch macupstream
git merge --no-commit --no-ff macupstream/master
git diff --cached --name-status --no-renames -z HEAD | while IFS= read -r -d '' st && IFS= read -r -d '' p; do
  case $p in Unix/*|docs/unix/*|.github/workflows/unix.yml|AI/Context/UNIX_CONTEXT.md|AI/Instructions/ShellConventions.md|AI/Skills/foundation/*|AI/Rules/example/*|FastFetch/Unix/*|Git/Unix/*|Btop/Unix/*|Btop/themes/*|WezTerm/*) continue ;; esac
  if git cat-file -e "HEAD:$p" 2>/dev/null; then git checkout HEAD -- "$p"; else git rm -q -f --cached -- "$p" && rm -f -- "$p"; fi
done
```

## Versions

Foundation's version says how much attention a merge needs (see `VERSIONING.md`). Before 1.0.0 any
release may rename or remove a command, flag, config line kind or Bootstrap step, with a migration
note in the changelog; read the notes of each release you merge. From 1.0.0 on, WinuX's ladder
applies: a MINOR only deprecates, keeping the old shape working, and removals wait for a MAJOR.
