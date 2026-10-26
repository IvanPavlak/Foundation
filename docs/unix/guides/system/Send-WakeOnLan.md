# Send-WakeOnLan

Sends a Wake-on-LAN magic packet to machines of `wake-on-lan.conf` and, for a machine with an
address, waits until it answers a ping.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`wake-on-lan.conf`](../../configuration.md#files) | `[Name]` | none | One machine; the menu lists the sections in file order, `--all` wakes every one |
| [`wake-on-lan.conf`](../../configuration.md#files) | `mac MAC` | none | The machine's MAC address, `-` or `:` separated; required |
| [`wake-on-lan.conf`](../../configuration.md#files) | `broadcast ADDRESS` | none | The subnet broadcast address the packet goes to; required |
| [`wake-on-lan.conf`](../../configuration.md#files) | `port PORT` | none, so `9` | The UDP port of the packet |
| [`wake-on-lan.conf`](../../configuration.md#files) | `address HOST` | none | Optional: pinged first (a machine that answers gets no packet) and after (wait until it answers, `--timeout-seconds`, default 120); `--no-wait` skips both pings; without it the wake is not confirmed and a warning says so |
| [`wake-on-lan.conf`](../../configuration.md#files) | `default NAME` | none | The machine an empty Enter at the menu wakes, and the one a `Send-WakeOnLan` workspace action without arguments wakes |

## Decisions

1. Which machines should Send-WakeOnLan wake?
    - Options: one `[Name]` section per machine with `mac` and `broadcast` lines; a section missing either is reported and skipped. `All` and `None` are not machine names: the menu and a name argument read them as wake every machine and cancel.
    - Default: none, so the command stops with "No machines in wake-on-lan.conf".
    - More detail: [`wake-on-lan.conf`](../../configuration.md#files)
2. Should Send-WakeOnLan know when a machine is up?
    - Options: an `address HOST` line (an IP address or a host name) in the machine's section; without it the packet is fire-and-forget, with a warning that the wake cannot be confirmed.
    - Default: no address.
    - More detail: [`wake-on-lan.conf`](../../configuration.md#files)
3. Which UDP port does the machine listen on?
    - Options: `port PORT`, usually `9` or `7`.
    - Default: `9`.
    - More detail: [`wake-on-lan.conf`](../../configuration.md#files)
4. Which machine should an empty Enter at the menu, or a workspace, wake?
    - Options: `default NAME` before the first section, naming a section.
    - Default: none, so an empty Enter wakes nothing and the workspace action warns and wakes nothing.
    - More detail: [`wake-on-lan.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/wake-on-lan.local.conf`, created when missing. The `default` line goes before the
first section and is added to the base lines (the last one wins). A `[Name]` section adds a
machine; a section with the name of a base one replaces it whole. Lines inside a section take
`@TYPE` like any other.

## Steps Overview

1. Add the machine section
2. Set the default machine
3. Check the configuration

## Step 1: Add the machine section

```conf
[MyServer]
mac        AA-BB-CC-DD-EE-FF
broadcast  192.168.1.255
address    192.168.1.10
port       9
```

## Step 2: Set the default machine

Before the first section:

```conf
default MyServer
```

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `@TYPE` prefix that names a machine type `machines.conf` does not have; a missing
`mac` or `broadcast` shows only when that machine is woken.

## Verification

```bash
Test-ConfigurationSchema --quiet
cat Unix/config/wake-on-lan.local.conf
Test-MachineOnline MyServer
```

`Test-MachineOnline` only pings the configured address.

## Complete Example

`Unix/config/wake-on-lan.local.conf`:

```conf
default MyServer

[MyServer]
mac        AA-BB-CC-DD-EE-FF
broadcast  192.168.1.255
address    192.168.1.10
port       9
```

## Related

- [`Send-WakeOnLan` in the System module reference](../../modules/System.md#send-wakeonlan)
- [Test-MachineOnline](Test-MachineOnline.md)
- [System configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
