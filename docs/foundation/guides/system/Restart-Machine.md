# Restart-Machine

Asks for confirmation, counts down 5 seconds, then restarts the Mac the way the Apple menu does,
so apps can save.

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
Restart-Machine
Restart-Machine --selection Yes
Restart-Machine --force
```

`--selection Yes` answers the prompt and still counts down; `--force` skips both.

## Related

- [`Restart-Machine` in the System module reference](../../modules/System.md#restart-machine)
- [System configuration guides](README.md)
