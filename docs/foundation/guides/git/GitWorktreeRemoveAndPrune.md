# GitWorktreeRemoveAndPrune

Prunes stale worktree entries, removes linked worktrees with `git worktree remove` (`--force` adds `--force`), and offers to delete their branches through `GitBranchDeleteAndPrune` (Yes, No or Force; Enter means No) (alias `gwd`). Without a worktree it offers the linked worktrees in a menu that takes one or more; the main, the current and locked worktrees are never offered, and Enter removes nothing.

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
GitWorktreeRemoveAndPrune feature/my-feature
gwd ../MyRepo-hotfix --force
gwd feature/a, feature/b
gwd    # pick one or more worktrees from a menu
```

## Related

- [`GitWorktreeRemoveAndPrune` in the Git module reference](../../modules/Git.md#gitworktreeremoveandprune)
- [GitBranchDeleteAndPrune](GitBranchDeleteAndPrune.md) - deletes the branches it hands over
- [Git configuration guides](README.md)
