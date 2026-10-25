# Get-ActiveWindowInfo

Prints the open windows with their app, desktop and frame and a ready-to-paste layout line, for
writing layout files.

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
Get-ActiveWindowInfo
Get-ActiveWindowInfo '*MyProject*'
Get-ActiveWindowInfo --continuous
Get-ActiveWindowInfo | pbcopy
```

## Related

- [`Get-ActiveWindowInfo` in the Window module reference](../../modules/Window.md#get-activewindowinfo)
- [Set-WorkspaceWindowLayout](Set-WorkspaceWindowLayout.md)
- [Window configuration guides](README.md)
