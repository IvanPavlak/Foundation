# Find-Item

Finds a file or directory by a case-insensitive name glob, level by level from the start path's subtree up through each parent's whole subtree (the nearest level with a match wins), and prints only the chosen path.

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
Find-Item "*.sln"
Find-Item Program.cs --start-path $DEV/MyRepo --max-downward-depth 8
cd "$(Find-Item src --directory --select-first)"
Find-Item "*.csproj" --name-filter Domain
```

## Related

- [`Find-Item` in the Helper module reference](../../modules/Helper.md#find-item)
- [Helper configuration guides](README.md)
