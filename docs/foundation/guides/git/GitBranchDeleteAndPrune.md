# GitBranchDeleteAndPrune

Force-deletes a local branch and prunes stale `origin` refs (alias `gbd`). Without a branch it offers the local branches in a menu that takes one or more; Enter deletes nothing.

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
GitBranchDeleteAndPrune feature/my-feature
gbd feature/my-feature
gbd    # pick one or more branches from a menu
```

## Related

- [`GitBranchDeleteAndPrune` in the Git module reference](../../modules/Git.md#gitbranchdeleteandprune)
- [Git configuration guides](README.md)
