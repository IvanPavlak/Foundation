# Merge-Upstreams

Merges one upstream project into the current branch by path ownership and stops before the
commit: each project's own paths come from it, `mirror` files from any upstream, and the hallway
(everything else) only from the root owner.

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

It reads two files from the repository instead, neither of them a `Unix/config` file with an
overlay: every project's manifest, a tracked file named `upstream.conf` (Foundation's is
[`Unix/config/upstream.conf`](../../configuration.md#upstreamconf), shipped by Foundation and
never edited by a fork), and the fork's optional settings file `Git/upstreams.local.conf`:

```conf
root-owner fork
take foundation .github/ISSUE_TEMPLATE/
```

`root-owner NAME|fork` says who owns the hallway (default: the only upstream when the repository
knows one, else `fork`); each `take UPSTREAM PATH` adopts a hallway path (a PATH ending in `/`
covers everything under it) from that upstream. See [Fork Model](../../fork-model.md).

## Usage

```bash
Merge-Upstreams foundation --dry-run
Merge-Upstreams foundation
Merge-Upstreams foundation --branch release
```

## Related

- [`Merge-Upstreams` in the Git module reference](../../modules/Git.md#merge-upstreams)
- [Git configuration guides](README.md)
- [Fork Model](../../fork-model.md)
