# Rename-Machine

Sets the Mac's ComputerName, HostName and LocalHostName to a name configured in `machines.conf`,
or to a new one.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`machines.conf`](../../configuration.md#files) | `host HOSTNAME TYPE` | none | The configured machine names: the menu offers them, and a Mac already named one of them is left alone unless `--override`. TYPE maps the name to a machine type for every other command |

The other `machines.conf` lines (`type`, `default`, `small-display`, `layout-override`,
`dev-root`) decide the machine type and the dev root of every command; Rename-Machine reads only
`host`.

## Decisions

1. Which names should this repository's Macs carry?
    - Options: one `host HOSTNAME TYPE` line per Mac (`host My-Mac Work`, `host My-MacBook Laptop`); HOSTNAME is what `scutil --get LocalHostName` prints after the rename (spaces become hyphens there): at most 63 characters, only letters, digits and hyphens, not digits alone, or Rename-Machine refuses it; TYPE a `type` line of `machines.conf`.
    - Default: none, so the menu cannot be shown and Rename-Machine needs the new name as an argument.
    - More detail: [`machines.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/machines.local.conf`, created when missing (Initialize-Configuration writes this
Mac's `host` line on a fresh clone). `machines.conf` has no sections: the overlay's lines are
added after the base lines, and `-LINE` takes a base line back.

## Steps Overview

1. Add the `host` lines
2. Check the configuration

## Step 1: Add the `host` lines

Each TYPE needs its own `type` line.

```conf
type Work
type Laptop
host My-Mac      Work
host My-MacBook  Laptop
```

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports a `host` line whose TYPE is not a `type` line of `machines.conf`.

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n '^host' Unix/config/machines.local.conf
scutil --get LocalHostName
```

## Complete Example

`Unix/config/machines.local.conf`:

```conf
type Work
type Laptop
host My-Mac      Work
host My-MacBook  Laptop
default Work
```

## Related

- [`Rename-Machine` in the System module reference](../../modules/System.md#rename-machine)
- [System configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
