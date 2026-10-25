# Test-GitRepository

Tells whether a path (default: the current directory) is inside a git repository, printing its root, without running git.

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
Test-GitRepository
Test-GitRepository $DEV/MyRepo
Test-GitRepository --quiet && echo inside
```

## Related

- [`Test-GitRepository` in the Git module reference](../../modules/Git.md#test-gitrepository)
- [Git configuration guides](README.md)
