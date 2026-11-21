# GitBranchDeleteAndPrune

Deletes local branches with `git branch -d` and prunes stale `origin` refs (alias `gbd`). A branch git refuses (not fully merged, squash-merged) is offered once for `git branch -D`; `--force` forces straight away. Without a branch it offers the local branches in a menu that takes one or more; Enter deletes nothing.

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
GitBranchDeleteAndPrune feature/my-feature
gbd feature/my-feature
gbd feature/a, feature/b --force
gbd    # pick one or more branches from a menu
```

## Related

- [`GitBranchDeleteAndPrune` in the Git module reference](../../modules/Git.md#gitbranchdeleteandprune)
- [GitWorktreeRemoveAndPrune](GitWorktreeRemoveAndPrune.md) - removes worktrees and hands their branches to this command
- [Git configuration guides](README.md)
