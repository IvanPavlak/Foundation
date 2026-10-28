# Invoke-Clear

Clears the terminal screen and its scrollback, the first step of the terminal greeting, unless
`greeting.conf` turns it off.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`greeting.conf`](../../configuration.md#files) | `clear on\|off` | `clear on` | Whether the greeting clears the screen; with `off` the command does nothing and the greeting draws below what is on screen |

The other `greeting.conf` lines belong to [Invoke-Fastfetch](Invoke-Fastfetch.md) and
[Invoke-Onefetch](Invoke-Onefetch.md).

## Decisions

1. Should every new shell (and `c`) clear the screen before drawing the greeting?
    - Options: `clear on` or `clear off`; only the exact value `off` turns it off. The last line for this machine type wins, so `@Laptop clear off` changes one machine type.
    - Default: `clear on` in the base file; without any line the screen is cleared too.
    - More detail: [`greeting.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/greeting.local.conf`, created when missing. `greeting.conf` has no sections: the
overlay's lines are added after the base lines and the last `clear` line wins, so one line in the
overlay overrides the base. `@TYPE` limits a line to machine types.

## Steps Overview

1. Add the `clear` line
2. Check the configuration

## Step 1: Add the `clear` line

```conf
clear off
```

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `@TYPE` prefix that names a machine type `machines.conf` does not have.

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n 'clear' Unix/config/greeting.conf Unix/config/greeting.local.conf
```

## Complete Example

`Unix/config/greeting.local.conf`:

```conf
clear on
@Laptop clear off
```

## Related

- [`Invoke-Clear` in the System module reference](../../modules/System.md#invoke-clear)
- [System configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
