# Merge-Upstream

Merges an upstream remote into the current branch and stops before the commit, and with
`--owned-only` takes only the paths `upstream.conf` says Foundation owns, so a fork of both WinuX
and Foundation takes each half from its own upstream.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`upstream.conf`](../../configuration.md#upstreamconf) | `own PATH` | every path Foundation ships (`Unix/`, `docs/unix/`, its AI, Git, Btop, FastFetch and WezTerm folders) | A path an owned-only merge takes; a folder ends in `/` and covers everything under it, any other PATH is one file |
| [`upstream.conf`](../../configuration.md#upstreamconf) | `mirror PATH` | the WinuX files Foundation ships unchanged (`LICENSE`, `Git/.gitconfig`, ...) | A file the fork takes from WinuX: an owned-only merge that meets a change to one says so |
| [`upstream.conf`](../../configuration.md#upstreamconf) | `owned-only REMOTE...` | none | The remotes whose merges are owned-only without `--owned-only`; `--all-paths` overrides it for one run |

## Decisions

1. Does this fork merge Foundation next to another upstream?
    - Options: yes (a fork of WinuX that also takes Foundation): name the Foundation remote on an `owned-only` line, so every merge from it takes only Foundation's paths; no (a fork of Foundation alone): leave it out, and a merge takes every path as a plain `git merge` would.
    - Default: no `owned-only` line; `--owned-only` on the call still asks for it.
    - More detail: [`upstream.conf`](../../configuration.md#upstreamconf)
2. Does the fork own paths under Foundation's that a merge must leave alone?
    - Options: keep them in the `.local.conf` overlays and the Custom area, which Foundation never ships, so no line is needed; for anything else, `-own PATH` in the overlay takes a base line back and the merge then treats that path as the fork's.
    - Default: every `own` line of the base applies.
    - More detail: [Fork Model](../../fork-model.md)

## Where to Put Values

`Unix/config/upstream.local.conf`, created by hand when missing. Its lines are added after the
base ones; `-LINE` takes a base line back (`-own WezTerm/`); `@TYPE` limits a line to machine
types.

## Steps Overview

1. Name the Foundation remote
2. Check what a merge would take

## Step 1: Name the Foundation remote

The remote itself is added once with `git remote add macupstream URL`; this line only makes its
merges owned-only:

```conf
owned-only macupstream
```

## Step 2: Check what a merge would take

```bash
Merge-Upstream macupstream --dry-run
```

It fetches the remote and lists the changed paths it would take and those it would take back,
merging nothing.

## Verification

```bash
Merge-Upstream macupstream --dry-run
cat Unix/config/upstream.local.conf
```

## Complete Example

`Unix/config/upstream.local.conf`:

```conf
owned-only macupstream
-own WezTerm/
```

## Related

- [`Merge-Upstream` in the Git module reference](../../modules/Git.md#merge-upstream)
- [Git configuration guides](README.md)
- [Fork Model](../../fork-model.md)
- [macOS Configurator](../../macos-configurator.md)
