# Add-SymbolicLink

Adds a dotfile link to the chezmoi source tree `Unix/home`: a one-line symlink template that
makes `~/HOME-PATH` a link to a repository file or folder once `chezmoi apply` runs.

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
Add-SymbolicLink HOME-PATH TARGET
Add-SymbolicLink .config/myapp/config.toml MyApp/config.toml
Add-SymbolicLink ~/.myapprc MyApp/.myapprc
Add-SymbolicLink -Path .config/myapp/extra.toml -Target MyApp/extra.toml
```

## Related

- [`Add-SymbolicLink` in the Configuration module reference](../../modules/Configuration.md#add-symboliclink)
- [Configuration configuration guides](README.md)
