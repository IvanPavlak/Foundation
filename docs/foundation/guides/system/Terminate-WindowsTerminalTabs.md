# Terminate-WindowsTerminalTabs

Closes every WezTerm tab except this one (its split panes included), or this one too, or only this pane; the name is kept from Windows.

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
Terminate-WindowsTerminalTabs
Terminate-WindowsTerminalTabs --include-current
Terminate-WindowsTerminalTabs --only-current
Terminate-WindowsTerminalTabs --only-current --close-wait-seconds 5
```

## Related

- [`Terminate-WindowsTerminalTabs` in the System module reference](../../modules/System.md#terminate-windowsterminaltabs)
- [System configuration guides](README.md)
