# Countdown

Counts down on one line (cyan above 3, red from 3) before a destructive operation; Ctrl+C aborts with exit status 130, so whatever follows `&&` does not run.

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
Countdown 5
Countdown 10 --message "Cleaning MyProject..." && dotnet clean
```

## Related

- [`Countdown` in the Helper module reference](../../modules/Helper.md#countdown)
- [Helper configuration guides](README.md)
