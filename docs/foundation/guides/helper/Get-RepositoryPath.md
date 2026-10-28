# Get-RepositoryPath

Prints the repository root, or its Unix, modules, Windows, config or docs folder, found by the anchor file `Unix/lib/foundation.sh` (walking up from the command, or from `--start-path DIR`). `windows` fails in a clone without a `Windows` folder.

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
Get-RepositoryPath
Get-RepositoryPath config
cd "$(Get-RepositoryPath docs)"
Get-RepositoryPath modules --start-path ~/Development/GitHub/MyRepo/Unix
```

## Related

- [`Get-RepositoryPath` in the Helper module reference](../../modules/Helper.md#get-repositorypath)
- [Helper configuration guides](README.md)
