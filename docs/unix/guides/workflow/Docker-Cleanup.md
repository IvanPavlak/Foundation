# Docker-Cleanup

Shows a menu of the Docker cleanup actions of `docker.conf` plus All, previews what the picked
ones would touch and runs them, after one confirmation when a picked entry carries one.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`docker.conf`](../../configuration.md#dockerconf) | `cleanup LABEL :: COMMAND [:: CONFIRMATION]` | Stop all containers, Delete all containers, Delete all images, Delete all volumes, Prune networks and build cache | One menu entry; picked entries run in the order of these lines. With a `CONFIRMATION` the run needs an explicit "yes" |
| [`docker.conf`](../../configuration.md#dockerconf) | `cleanup-description LABEL :: TEXT` | one sentence per base entry | The sentence printed next to the label before anything runs |
| [`docker.conf`](../../configuration.md#dockerconf) | `cleanup-preview LABEL :: COMMAND` | one listing command per base entry | Lists what the entry would stop or remove; an empty list skips the entry |
| [`docker.conf`](../../configuration.md#dockerconf) | `cleanup-start ask\|always\|never` | `ask` | What happens when the Docker daemon is down: ask (Enter means yes; without a terminal no, so nothing starts), start Docker without asking, or warn and stop |
| [`docker.conf`](../../configuration.md#dockerconf) | `timeout start SECONDS` | `180` | How long to wait for the daemon after starting Docker Desktop |

## Decisions

1. Which cleanup actions should the menu offer?
    - Options: `cleanup` lines, each `LABEL :: COMMAND`, the command run by `bash -c`; keep stops and container deletes above images and volumes, because picked entries run in file order. All runs every line.
    - Default: the five base entries (stop and delete containers, delete images and volumes, prune networks and build cache).
    - More detail: [`docker.conf`](../../configuration.md#dockerconf)
2. Which actions need a confirmation?
    - Options: a third `:: CONFIRMATION` field on the line. One red prompt covers the whole run when any picked entry has one (that entry's own message when it is the only one) and only "yes" goes ahead; a run whose entries have none starts without a prompt.
    - Default: every base entry has a confirmation.
    - More detail: [`docker.conf`](../../configuration.md#dockerconf)
3. Should each action explain itself and show what it would touch?
    - Options: a `cleanup-description LABEL :: TEXT` and a `cleanup-preview LABEL :: COMMAND` line per entry, matched to the entry by label (case-insensitive). A preview that lists nothing skips the entry.
    - Default: without them the label alone is printed and the entry always runs.
    - More detail: [`docker.conf`](../../configuration.md#dockerconf)
4. What should happen when Docker is not running?
    - Options: `cleanup-start ask` (Enter means yes, no terminal means no), `always` or `never`; an empty or unknown value means `ask`. `timeout start SECONDS` bounds the wait for the daemon.
    - Default: `ask`, waiting up to 180 seconds.
    - More detail: [`docker.conf`](../../configuration.md#dockerconf)

## Where to Put Values

`Unix/config/docker.local.conf`, created when missing. `docker.conf` has no sections: the overlay's
lines are added after the base ones, so its `cleanup` lines follow the base entries in the menu and
in the run order. For `cleanup-start` and `timeout start` the overlay's line wins. To take a base
entry back, repeat it with a leading `-` (`-cleanup Delete all images :: ...`, the whole line);
`@TYPE` limits a line to machine types.

## Steps Overview

1. Add a cleanup action
2. Choose what happens when Docker is down
3. Check the configuration

## Step 1: Add a cleanup action

```conf
cleanup Delete dangling images :: docker image prune -f :: Are you sure you want to delete dangling images?
cleanup-description Delete dangling images :: Removes images no tag points at.
cleanup-preview Delete dangling images :: docker images -f dangling=true --format '{{.ID}} ({{.Size}})'
```

## Step 2: Choose what happens when Docker is down

```conf
cleanup-start always
timeout start 240
```

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It does not parse the `cleanup` lines; read them back with `grep` instead (Verification).

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n '^-\?cleanup' Unix/config/docker.conf Unix/config/docker.local.conf
```

## Complete Example

`Unix/config/docker.local.conf`:

```conf
cleanup-start always
timeout start 240
-cleanup Delete all images :: docker images -aq | sort -u | xargs docker rmi -f :: Are you sure you want to delete ALL images?
cleanup Delete dangling images :: docker image prune -f :: Are you sure you want to delete dangling images?
cleanup-description Delete dangling images :: Removes images no tag points at.
cleanup-preview Delete dangling images :: docker images -f dangling=true --format '{{.ID}} ({{.Size}})'
```

## Related

- [`Docker-Cleanup` in the Workflow module reference](../../modules/Workflow.md#docker-cleanup)
- [Start-Containers](Start-Containers.md)
- [Workflow configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
