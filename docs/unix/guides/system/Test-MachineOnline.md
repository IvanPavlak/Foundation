# Test-MachineOnline

Pings a machine of `wake-on-lan.conf` at its address, or any IP address or host name, once or
until it answers; exit status 0 when online.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`wake-on-lan.conf`](../../configuration.md#files) | `[Name]` | none | A machine name Test-MachineOnline accepts in place of an address (case-insensitive) |
| [`wake-on-lan.conf`](../../configuration.md#files) | `address HOST` | none | What is pinged for that machine; a configured machine without one is reported and fails (exit status 1) |

The `mac`, `broadcast`, `port` and `default` lines of the same file belong to
[Send-WakeOnLan](Send-WakeOnLan.md).

## Decisions

1. Which machines should be testable by name?
    - Options: a `[Name]` section with an `address HOST` line (an IP address or a host name) per machine. A name that is not a section is pinged as an address itself.
    - Default: none, so every argument is pinged as given.
    - More detail: [`wake-on-lan.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/wake-on-lan.local.conf`, created when missing. A `[Name]` section adds a machine; a
section with the name of a base one replaces it whole, so copy every line you keep. Lines inside
a section take `@TYPE` like any other.

## Steps Overview

1. Add the address
2. Check the configuration

## Step 1: Add the address

```conf
[MyServer]
address 192.168.1.10
```

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `@TYPE` prefix that names a machine type `machines.conf` does not have.

## Verification

```bash
Test-ConfigurationSchema --quiet
Test-MachineOnline MyServer
```

## Complete Example

`Unix/config/wake-on-lan.local.conf`:

```conf
[MyServer]
mac        AA-BB-CC-DD-EE-FF
broadcast  192.168.1.255
address    192.168.1.10
port       9
```

## Related

- [`Test-MachineOnline` in the System module reference](../../modules/System.md#test-machineonline)
- [Send-WakeOnLan](Send-WakeOnLan.md)
- [System configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
